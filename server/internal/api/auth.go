package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

// phonePattern 是大陆手机号。
//
// 前端也有一份同样的正则，但那份只为即时反馈（按钮该不该亮）—— 服务端这份才是
// 权威，因为前端可以被绕过，而手机号是后续所有限流的键。
var phonePattern = regexp.MustCompile(`^1[3-9]\d{9}$`)

const (
	maxAuthBodyBytes = 4 << 10
	smsCodeLength    = 6

	// smsResendInterval 同一号码两次发送的最小间隔。
	// 前端按钮的倒计时用的就是它，通过响应里的 retryAfterSeconds 下发 ——
	// 前端不硬编码这个数字，否则两边一改就对不上。
	smsResendInterval = 60 * time.Second

	// smsDailyLimit 同一号码 24 小时内的发送总量上限。
	// 防的是拿这个接口当短信轰炸器 —— 真正的成本在短信费上。
	smsDailyLimit = 10

	// smsMaxAttempts 单个验证码允许的最大校验失败次数，超过即作废。
	// 没有它，6 位码可以被在线暴力枚举出来。
	smsMaxAttempts = 5
)

type smsSendRequest struct {
	Phone string `json:"phone"`
}

type smsVerifyRequest struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

type smsSendResponse struct {
	ExpiresInSeconds  int `json:"expiresInSeconds"`
	RetryAfterSeconds int `json:"retryAfterSeconds"`
	// DevCode 只在 development 下出现。
	// 用 *string 而非 string：配合 omitempty，指针能把「这个字段不该存在」
	// 表达得比空串更明确，也让「忘了填」不会被静默当成「生产环境」。
	DevCode *string `json:"devCode,omitempty"`
}

type loginResponse struct {
	Token string      `json:"token"`
	User  models.User `json:"user"`
	// IsNewUser 表示这次登录顺带完成了注册。前端据此决定要不要说一句
	// 「欢迎新用户」，而不是让它自己去猜。
	IsNewUser bool `json:"isNewUser"`
}

// PostSmsSend 发送验证码。
//
// 免鉴权 —— 它就是用来换取 token 的，要求带 token 会变成死循环。
func (h *Handler) PostSmsSend(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAuthBodyBytes)

	var req smsSendRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		abortBadJSON(c, err)
		return
	}
	phone := strings.TrimSpace(req.Phone)
	if !phonePattern.MatchString(phone) {
		abortInvalidPhone(c, phone)
		return
	}

	ctx := c.Request.Context()
	now := time.Now().UTC()

	// 重发间隔。取最近一条记录，不论是否已被消费 ——
	// 限流针对的是「发送」这个动作，跟用户后来有没有用掉这个码无关。
	latest, err := h.Auth.LatestSmsCode(ctx, phone)
	switch {
	case err == nil:
		if elapsed := now.Sub(latest.CreatedAt); elapsed < smsResendInterval {
			httputil.Abort(c, http.StatusTooManyRequests, httputil.CodeRateLimited,
				"验证码发送过于频繁，请稍后再试",
				map[string]any{
					// +1 向上取整：剩余 0.4 秒时报「0 秒后可重试」会让前端
					// 立刻放行按钮，然后被服务端再拒一次。
					"retryAfterSeconds": int((smsResendInterval - elapsed).Seconds()) + 1,
				})
			return
		}
	case errors.Is(err, store.ErrNotFound):
		// 从未发过，不构成限流。
	default:
		abortInternal(c)
		return
	}

	sent, err := h.Auth.CountSmsCodesSince(ctx, phone, now.Add(-24*time.Hour))
	if err != nil {
		abortInternal(c)
		return
	}
	if sent >= smsDailyLimit {
		httputil.Abort(c, http.StatusTooManyRequests, httputil.CodeRateLimited,
			"今日验证码发送次数已达上限，请明天再试", nil)
		return
	}

	// 非 development 一律用随机码。DevCode 为空即代表不在开发环境。
	var code string
	if h.SMS.DevCode != "" {
		code = h.SMS.DevCode
	} else if code, err = randomDigits(smsCodeLength); err != nil {
		abortInternal(c)
		return
	}

	ttl := h.SMS.ttl()
	if err := h.Auth.CreateSmsCode(ctx, phone, code, now.Add(ttl)); err != nil {
		abortInternal(c)
		return
	}

	if h.SMS.Sender != nil {
		if err := h.SMS.Sender.Send(ctx, phone, code); err != nil {
			// 发不出去就别留下一个用户永远收不到的码：它会让接下来的
			// 60 秒重发被拦，用户陷入「点了没反应，再点说太频繁」。
			abortInternal(c)
			return
		}
	}

	resp := smsSendResponse{
		ExpiresInSeconds:  int(ttl.Seconds()),
		RetryAfterSeconds: int(smsResendInterval.Seconds()),
	}
	if h.SMS.DevCode != "" {
		dev := code
		resp.DevCode = &dev
	}
	c.JSON(http.StatusOK, resp)
}

// PostSmsVerify 校验验证码并签发 token；号码未注册时顺带完成注册。
func (h *Handler) PostSmsVerify(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAuthBodyBytes)

	var req smsVerifyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		abortBadJSON(c, err)
		return
	}
	phone := strings.TrimSpace(req.Phone)
	code := strings.TrimSpace(req.Code)
	if !phonePattern.MatchString(phone) {
		abortInvalidPhone(c, phone)
		return
	}
	if !isDigits(code, smsCodeLength) {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"验证码格式不正确", map[string]any{"code": code})
		return
	}

	ctx := c.Request.Context()
	now := time.Now().UTC()

	latest, err := h.Auth.LatestSmsCode(ctx, phone)
	if errors.Is(err, store.ErrNotFound) {
		abortCodeExpired(c)
		return
	}
	if err != nil {
		abortInternal(c)
		return
	}

	// 三种不可用情形合并成同一个错误码：对用户而言引导是同一句
	// 「请重新获取验证码」，再细分只会泄漏「这个码存在但已用过」这类信息。
	if latest.ConsumedAt != nil || latest.Attempts >= smsMaxAttempts || !now.Before(latest.ExpiresAt) {
		abortCodeExpired(c)
		return
	}

	if latest.Code != code {
		if err := h.Auth.IncreaseSmsAttempts(ctx, latest.ID); err != nil {
			abortInternal(c)
			return
		}
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeSmsCodeInvalid,
			"验证码错误", nil)
		return
	}

	// 条件更新：影响行数为 0 表示已被别的请求抢先消费（连点两次登录按钮）。
	if err := h.Auth.ConsumeSmsCode(ctx, latest.ID, now); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			abortCodeExpired(c)
			return
		}
		abortInternal(c)
		return
	}

	userID, isNewUser, err := h.resolveUserByPhone(ctx, phone)
	if err != nil {
		abortInternal(c)
		return
	}

	user, err := h.Users.GetUser(ctx, userID)
	if err != nil {
		abortInternal(c)
		return
	}

	token, err := randomHex(32)
	if err != nil {
		abortInternal(c)
		return
	}
	if err := h.Tokens.CreateToken(ctx, token, userID); err != nil {
		abortInternal(c)
		return
	}

	c.JSON(http.StatusOK, loginResponse{Token: token, User: user, IsNewUser: isNewUser})
}

// resolveUserByPhone 返回该号码对应的用户 ID；没有就注册一个。
func (h *Handler) resolveUserByPhone(ctx context.Context, phone string) (string, bool, error) {
	userID, err := h.Auth.UserIDByPhone(ctx, phone)
	if err == nil {
		return userID, false, nil
	}
	if !errors.Is(err, store.ErrNotFound) {
		return "", false, err
	}

	id, err := newUserID()
	if err != nil {
		return "", false, err
	}
	if err := h.Auth.CreateUserWithPhone(ctx, models.NewUserForPhone(id, phone), phone); err != nil {
		// 并发下另一次请求刚刚注册了同一号码（用户连点两次登录按钮）。
		// 复用它，而不是把一个 500 抛给一个其实已经成功的登录。
		if errors.Is(err, store.ErrDuplicate) {
			userID, err := h.Auth.UserIDByPhone(ctx, phone)
			return userID, false, err
		}
		return "", false, err
	}
	return id, true, nil
}

// --- 小工具 ---

func abortInternal(c *gin.Context) {
	httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
		"服务器内部错误", nil)
}

func abortCodeExpired(c *gin.Context) {
	httputil.Abort(c, http.StatusBadRequest, httputil.CodeSmsCodeExpired,
		"验证码不存在或已过期，请重新获取", nil)
}

func abortInvalidPhone(c *gin.Context, phone string) {
	httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
		"手机号格式不正确", map[string]any{"phone": phone})
}

// abortBadJSON 与 preferences.go 的处理保持一致：超限与格式错误分开报，
// 都用 400 INVALID_PARAMETER（契约里 413 专指上传图片过大）。
func abortBadJSON(c *gin.Context, err error) {
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"请求体过大", nil)
		return
	}
	httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
		"请求体不是合法 JSON", nil)
}

func isDigits(s string, n int) bool {
	if len(s) != n {
		return false
	}
	for i := 0; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return false
		}
	}
	return true
}

// randomDigits 用 crypto/rand 而不是 math/rand：可预测的验证码等于没有验证码。
func randomDigits(n int) (string, error) {
	var b strings.Builder
	b.Grow(n)
	for i := 0; i < n; i++ {
		d, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", fmt.Errorf("生成验证码失败: %w", err)
		}
		b.WriteByte(byte('0' + d.Int64()))
	}
	return b.String(), nil
}

// randomHex 返回 n 字节的十六进制串（长度 2n）。
func randomHex(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("生成随机串失败: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

// newUserID 生成 u_ 前缀的随机 ID。
// 不用自增：种子用户是 u_1/u_2/u_3，自增要么撞号要么得先查最大值。
func newUserID() (string, error) {
	suffix, err := randomHex(4)
	if err != nil {
		return "", err
	}
	return "u_" + suffix, nil
}
