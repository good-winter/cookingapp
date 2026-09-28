package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/auth"
	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

const testPhone = "13900000001"

// fakeAuth 是 AuthStore 的内存实现。
//
// 它**不是**桩：真的维护状态（验证码会被消费、失败会累加、用户会被创建），
// 所以「同一个码不能用两次」「错 5 次就作废」这类断言测的是行为，
// 而不是「我喂给桩的返回值被原样吐了回来」。
//
// users 与 fakeUsers.user 是同一张 map，对应线上两者读写同一张 users 表 ——
// 否则「注册后紧接着 GetUser」在测试里会查不到，而线上不会。
type fakeAuth struct {
	codes  []models.SmsCode
	phone  map[string]string
	users  map[string]models.User
	nextID int64
}

func (f *fakeAuth) LatestSmsCode(_ context.Context, phone string) (models.SmsCode, error) {
	for i := len(f.codes) - 1; i >= 0; i-- {
		if f.codes[i].Phone == phone {
			return f.codes[i], nil
		}
	}
	return models.SmsCode{}, store.ErrNotFound
}

func (f *fakeAuth) CreateSmsCode(_ context.Context, phone, code string, expiresAt time.Time) error {
	f.nextID++
	f.codes = append(f.codes, models.SmsCode{
		ID: f.nextID, Phone: phone, Code: code,
		ExpiresAt: expiresAt, CreatedAt: time.Now().UTC(),
	})
	return nil
}

func (f *fakeAuth) ConsumeSmsCode(_ context.Context, id int64, at time.Time) error {
	for i := range f.codes {
		if f.codes[i].ID != id {
			continue
		}
		if f.codes[i].ConsumedAt != nil {
			return store.ErrNotFound
		}
		t := at
		f.codes[i].ConsumedAt = &t
		return nil
	}
	return store.ErrNotFound
}

func (f *fakeAuth) IncreaseSmsAttempts(_ context.Context, id int64) error {
	for i := range f.codes {
		if f.codes[i].ID == id {
			f.codes[i].Attempts++
			return nil
		}
	}
	return store.ErrNotFound
}

func (f *fakeAuth) CountSmsCodesSince(
	_ context.Context, phone string, since time.Time,
) (int, error) {
	n := 0
	for _, c := range f.codes {
		if c.Phone == phone && !c.CreatedAt.Before(since) {
			n++
		}
	}
	return n, nil
}

func (f *fakeAuth) UserIDByPhone(_ context.Context, phone string) (string, error) {
	if id, ok := f.phone[phone]; ok {
		return id, nil
	}
	return "", store.ErrNotFound
}

func (f *fakeAuth) CreateUserWithPhone(_ context.Context, u models.User, phone string) error {
	if _, ok := f.phone[phone]; ok {
		return store.ErrDuplicate
	}
	f.phone[phone] = u.ID
	f.users[u.ID] = u
	return nil
}

// authTestRouter 返回一个开发环境的路由（因此 devCode 启用）、
// 以及背后的假 store，便于用例直接预置验证码。
func authTestRouter(t *testing.T, seed map[string]models.User) (*gin.Engine, *fakeAuth) {
	t.Helper()
	users := map[string]models.User{}
	for id, u := range seed {
		users[id] = u
	}
	a := &fakeAuth{phone: map[string]string{}, users: users}
	h := &Handler{
		Users:  fakeUsers{user: users},
		Tokens: fakeTokens{valid: map[string]string{}},
		Auth:   a,
		SMS: SMSAuth{
			Sender:  auth.DevSender{},
			CodeTTL: 5 * time.Minute,
			DevCode: "123456",
		},
	}
	return testRouterWith(h), a
}

func postJSON(t *testing.T, r *gin.Engine, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func errorCode(t *testing.T, w *httptest.ResponseRecorder) string {
	t.Helper()
	var body struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("响应不是合法 JSON: %v，body=%s", err, w.Body.String())
	}
	return body.Error.Code
}

func mustLogin(t *testing.T, r *gin.Engine, auth *fakeAuth) loginResponse {
	t.Helper()
	// 直插一条验证码，绕过 60 秒重发间隔 —— 这里要测的是校验逻辑，
	// 不是限流（限流另有专门用例）。
	auth.nextID++
	auth.codes = append(auth.codes, models.SmsCode{
		ID: auth.nextID, Phone: testPhone, Code: "123456",
		ExpiresAt: time.Now().UTC().Add(5 * time.Minute),
		CreatedAt: time.Now().UTC(),
	})
	w := postJSON(t, r, "/api/v1/auth/sms/verify",
		`{"phone":"`+testPhone+`","code":"123456"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("登录应成功，实际 %d，body=%s", w.Code, w.Body.String())
	}
	var resp loginResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("解析登录响应失败: %v", err)
	}
	return resp
}

// --- 发送 ---

// 这条是 router 重构的回归网：/auth/* 若被误挂到鉴权组下，
// 症状是「登录接口要求先登录」，用户永远进不去。
func TestSmsSendDoesNotRequireAuth(t *testing.T) {
	r, _ := authTestRouter(t, nil)
	w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`)
	if w.Code == http.StatusUnauthorized {
		t.Fatalf("发送验证码必须免鉴权，却返回了 401：%s", w.Body.String())
	}
	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", w.Code, w.Body.String())
	}
}

func TestSmsVerifyDoesNotRequireAuth(t *testing.T) {
	r, _ := authTestRouter(t, nil)
	w := postJSON(t, r, "/api/v1/auth/sms/verify", `{"phone":"`+testPhone+`","code":"000000"}`)
	if w.Code == http.StatusUnauthorized {
		t.Fatalf("校验验证码必须免鉴权，却返回了 401：%s", w.Body.String())
	}
}

func TestSmsSendReturnsDevCodeInDevelopment(t *testing.T) {
	r, _ := authTestRouter(t, nil)
	w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`)

	var resp smsSendResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("解析响应失败: %v", err)
	}
	if resp.DevCode == nil || *resp.DevCode != "123456" {
		t.Fatalf("开发环境应在响应里回显 devCode，实际 %v", resp.DevCode)
	}
	if resp.ExpiresInSeconds != 300 {
		t.Errorf("期望 expiresInSeconds=300，实际 %d", resp.ExpiresInSeconds)
	}
	// 前端靠这个值驱动倒计时，为 0 会让按钮立刻可点、点了又被 429 拦。
	if resp.RetryAfterSeconds != 60 {
		t.Errorf("期望 retryAfterSeconds=60，实际 %d", resp.RetryAfterSeconds)
	}
}

// 生产环境绝不能回显验证码 —— 那等于把登录凭证直接发给任何人。
func TestSmsSendOmitsDevCodeOutsideDevelopment(t *testing.T) {
	a := &fakeAuth{phone: map[string]string{}, users: map[string]models.User{}}
	r := NewRouter(config.Config{Env: "production"}, &Handler{
		Users:  fakeUsers{user: map[string]models.User{}},
		Tokens: fakeTokens{valid: map[string]string{}},
		Auth:   a,
		// DevCode 留空 —— 这正是 main.go 在非 development 下的行为。
		SMS: SMSAuth{Sender: auth.DevSender{}, CodeTTL: 5 * time.Minute},
	})

	w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", w.Code, w.Body.String())
	}
	if contains(w.Body.String(), "devCode") {
		t.Fatalf("非开发环境不得回显验证码，实际 body=%s", w.Body.String())
	}
	// 同时确认用的是随机码，而不是碰巧等于开发期的固定码。
	latest, err := a.LatestSmsCode(context.Background(), testPhone)
	if err != nil {
		t.Fatalf("应已写入验证码: %v", err)
	}
	if latest.Code == "123456" {
		t.Error("非开发环境不得使用开发期固定码")
	}
	if !isDigits(latest.Code, smsCodeLength) {
		t.Errorf("验证码应为 %d 位数字，实际 %q", smsCodeLength, latest.Code)
	}
}

func TestSmsSendRejectsInvalidPhone(t *testing.T) {
	for _, phone := range []string{"12345", "23900000001", "1390000000", "139000000012", "abcdefghijk"} {
		r, _ := authTestRouter(t, nil)
		w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+phone+`"}`)
		if w.Code != http.StatusBadRequest || errorCode(t, w) != "INVALID_PARAMETER" {
			t.Errorf("手机号 %q 应被拒为 400 INVALID_PARAMETER，实际 %d %s",
				phone, w.Code, w.Body.String())
		}
	}
}

func TestSmsSendRateLimitsResend(t *testing.T) {
	r, _ := authTestRouter(t, nil)
	if w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`); w.Code != http.StatusOK {
		t.Fatalf("首次发送应成功，实际 %d", w.Code)
	}

	w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`)
	if w.Code != http.StatusTooManyRequests || errorCode(t, w) != "RATE_LIMITED" {
		t.Fatalf("60 秒内重发应 429 RATE_LIMITED，实际 %d %s", w.Code, w.Body.String())
	}
	// 必须带上剩余秒数：前端拿它驱动倒计时，缺了就只能自己猜。
	if !contains(w.Body.String(), "retryAfterSeconds") {
		t.Errorf("限流响应应带 retryAfterSeconds，实际 %s", w.Body.String())
	}
}

// 重发间隔与当日上限是两条独立的限制，这条专门压上限。
func TestSmsSendEnforcesDailyLimit(t *testing.T) {
	r, a := authTestRouter(t, nil)
	// 时间戳往前挪一小时：跳过 60 秒间隔，只让当日总量生效。
	for i := 0; i < smsDailyLimit; i++ {
		a.codes = append(a.codes, models.SmsCode{
			ID: int64(i + 1), Phone: testPhone, Code: "123456",
			ExpiresAt: time.Now().UTC().Add(time.Minute),
			CreatedAt: time.Now().UTC().Add(-time.Hour),
		})
	}

	w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`)
	if w.Code != http.StatusTooManyRequests || errorCode(t, w) != "RATE_LIMITED" {
		t.Fatalf("超出当日上限应 429 RATE_LIMITED，实际 %d %s", w.Code, w.Body.String())
	}
}

// --- 校验 ---

func TestSmsVerifyRejectsWrongCode(t *testing.T) {
	r, a := authTestRouter(t, nil)
	if w := postJSON(t, r, "/api/v1/auth/sms/send", `{"phone":"`+testPhone+`"}`); w.Code != http.StatusOK {
		t.Fatalf("发送应成功，实际 %d", w.Code)
	}

	w := postJSON(t, r, "/api/v1/auth/sms/verify", `{"phone":"`+testPhone+`","code":"000000"}`)
	if w.Code != http.StatusBadRequest || errorCode(t, w) != "SMS_CODE_INVALID" {
		t.Fatalf("错误验证码应 400 SMS_CODE_INVALID，实际 %d %s", w.Code, w.Body.String())
	}

	latest, _ := a.LatestSmsCode(context.Background(), testPhone)
	if latest.Attempts != 1 {
		t.Errorf("失败次数应累加为 1，实际 %d", latest.Attempts)
	}
}

func TestSmsVerifyRejectsExpiredCode(t *testing.T) {
	r, a := authTestRouter(t, nil)
	a.codes = append(a.codes, models.SmsCode{
		ID: 1, Phone: testPhone, Code: "123456",
		ExpiresAt: time.Now().UTC().Add(-time.Second),
		CreatedAt: time.Now().UTC().Add(-10 * time.Minute),
	})

	w := postJSON(t, r, "/api/v1/auth/sms/verify", `{"phone":"`+testPhone+`","code":"123456"}`)
	if w.Code != http.StatusBadRequest || errorCode(t, w) != "SMS_CODE_EXPIRED" {
		t.Fatalf("过期验证码应 400 SMS_CODE_EXPIRED，实际 %d %s", w.Code, w.Body.String())
	}
}

// 验证码是一次性的：连点两次登录按钮不该换来两个 token。
func TestSmsVerifyRejectsReusedCode(t *testing.T) {
	r, a := authTestRouter(t, nil)
	mustLogin(t, r, a)

	// 同一个码再验一次。用 verify 而不是 send，才能确认拒的是「已消费」
	// 而不是被 60 秒限流挡住。
	w := postJSON(t, r, "/api/v1/auth/sms/verify", `{"phone":"`+testPhone+`","code":"123456"}`)
	if w.Code != http.StatusBadRequest || errorCode(t, w) != "SMS_CODE_EXPIRED" {
		t.Fatalf("已消费的验证码应被拒为 SMS_CODE_EXPIRED，实际 %d %s", w.Code, w.Body.String())
	}
}

// 没有失败次数上限，6 位码可以被在线枚举出来。
func TestSmsVerifyLocksAfterMaxAttempts(t *testing.T) {
	r, a := authTestRouter(t, nil)
	a.codes = append(a.codes, models.SmsCode{
		ID: 1, Phone: testPhone, Code: "123456",
		ExpiresAt: time.Now().UTC().Add(5 * time.Minute),
		CreatedAt: time.Now().UTC(),
		Attempts:  smsMaxAttempts,
	})

	// 此时即使输对也不放行 —— 这个码已经作废，必须重新获取。
	w := postJSON(t, r, "/api/v1/auth/sms/verify", `{"phone":"`+testPhone+`","code":"123456"}`)
	if w.Code != http.StatusBadRequest || errorCode(t, w) != "SMS_CODE_EXPIRED" {
		t.Fatalf("超过尝试上限后即使码正确也应被拒，实际 %d %s", w.Code, w.Body.String())
	}
}

// --- 登录与注册 ---

func TestSmsVerifyRegistersNewUser(t *testing.T) {
	r, a := authTestRouter(t, nil)
	resp := mustLogin(t, r, a)

	if !resp.IsNewUser {
		t.Error("首次登录的号码应标记 isNewUser=true")
	}
	if resp.Token == "" {
		t.Fatal("应签发 token")
	}
	if resp.User.Nickname != "用户0001" {
		t.Errorf("默认昵称应为 用户+后四位，实际 %q", resp.User.Nickname)
	}
	if resp.User.Timezone != "Asia/Shanghai" {
		t.Errorf("默认时区应为 Asia/Shanghai，实际 %q", resp.User.Timezone)
	}
	// 空数组必须序列化成 []，不是 null —— 前端直接按列表渲染。
	if !contains(mustMarshal(t, resp.User), `"crowds":[]`) {
		t.Errorf("新用户的空偏好应输出 []，实际 %s", mustMarshal(t, resp.User))
	}
}

func TestSmsVerifyReusesExistingUser(t *testing.T) {
	const existingID = "u_existing"
	r, a := authTestRouter(t, map[string]models.User{
		existingID: {
			ID: existingID, Nickname: "老用户", AvatarText: "老",
			Timezone: "Asia/Shanghai", Preferences: models.NewPreferences("normal", nil, nil),
		},
	})
	a.phone[testPhone] = existingID

	resp := mustLogin(t, r, a)
	if resp.IsNewUser {
		t.Error("已注册号码登录不应标记 isNewUser")
	}
	if resp.User.ID != existingID {
		t.Errorf("应返回已存在用户 %s，实际 %s", existingID, resp.User.ID)
	}
	if resp.User.Nickname != "老用户" {
		t.Errorf("不应改写已存在用户的资料，实际昵称 %q", resp.User.Nickname)
	}
}

// 签发出来的 token 必须能直接过鉴权中间件 —— 这条把「登录」与「其它接口」
// 接在一起，避免出现「登录成功但拿到的 token 用不了」。
func TestIssuedTokenIsAcceptedByAuthMiddleware(t *testing.T) {
	r, a := authTestRouter(t, nil)
	resp := mustLogin(t, r, a)

	w := getWithToken(t, r, "/api/v1/me", resp.Token)
	if w.Code != http.StatusOK {
		t.Fatalf("新签发的 token 应能访问 /me，实际 %d，body=%s", w.Code, w.Body.String())
	}
	if !contains(w.Body.String(), resp.User.ID) {
		t.Errorf("应返回该 token 对应的用户 %s，实际 %s", resp.User.ID, w.Body.String())
	}
}

// 无效 token 仍须被拒 —— 防止上面的用例是靠「中间件被拆掉了」才通过的。
func TestUnknownTokenIsRejected(t *testing.T) {
	r, _ := authTestRouter(t, nil)
	w := getWithToken(t, r, "/api/v1/me", "not-a-real-token")
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未知 token 应 401，实际 %d", w.Code)
	}
}

func mustMarshal(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("序列化失败: %v", err)
	}
	return string(b)
}
