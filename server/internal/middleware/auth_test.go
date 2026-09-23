package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/store"
)

type fakeTokens struct{ valid map[string]string }

func (f fakeTokens) UserIDByToken(_ context.Context, token string) (string, error) {
	if id, ok := f.valid[token]; ok {
		return id, nil
	}
	return "", store.ErrNotFound
}

// failTokens 用于验证「依赖故障」不等于「凭据无效」。
type failTokens struct{}

func (failTokens) UserIDByToken(context.Context, string) (string, error) {
	return "", context.DeadlineExceeded
}

func newTestRouter(tokens store.TokenStore, allowDebug bool) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/probe", Auth(tokens, allowDebug), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"userID": c.GetString(ContextUserID)})
	})
	return r
}

// do 返回状态码与「要么是 userID、要么是 error.code」。
func do(t *testing.T, r *gin.Engine, headers map[string]string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var body struct {
		UserID string `json:"userID"`
		Error  struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &body)
	if body.Error.Code != "" {
		return w.Code, body.Error.Code
	}
	return w.Code, body.UserID
}

func TestAuthAcceptsValidBearerToken(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, got := do(t, r, map[string]string{"Authorization": "Bearer dev-token-user-1"})
	if code != http.StatusOK || got != "u_1" {
		t.Fatalf("期望 200 + u_1，实际 %d + %q", code, got)
	}
}

func TestAuthIsCaseInsensitiveOnSchemeName(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"tk": "u_1"}}, true)
	code, got := do(t, r, map[string]string{"Authorization": "bearer tk"})
	if code != http.StatusOK || got != "u_1" {
		t.Fatalf("方案名应大小写不敏感，实际 %d + %q", code, got)
	}
}

func TestAuthRejectsMissingHeader(t *testing.T) {
	r := newTestRouter(fakeTokens{}, true)
	code, errCode := do(t, r, nil)
	if code != http.StatusUnauthorized || errCode != "UNAUTHORIZED" {
		t.Fatalf("期望 401 + UNAUTHORIZED，实际 %d + %q", code, errCode)
	}
}

func TestAuthRejectsUnknownToken(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, errCode := do(t, r, map[string]string{"Authorization": "Bearer 乱写的"})
	if code != http.StatusUnauthorized || errCode != "UNAUTHORIZED" {
		t.Fatalf("期望 401 + UNAUTHORIZED，实际 %d + %q", code, errCode)
	}
}

func TestAuthRejectsNonBearerScheme(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, _ := do(t, r, map[string]string{"Authorization": "Basic dev-token-user-1"})
	if code != http.StatusUnauthorized {
		t.Fatalf("非 Bearer 方案应拒绝，实际 %d", code)
	}
}

// 空 token（"Bearer " 后面什么都没有）不能放行。
func TestAuthRejectsEmptyToken(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"": "u_1"}}, true)
	code, _ := do(t, r, map[string]string{"Authorization": "Bearer "})
	if code != http.StatusUnauthorized {
		t.Fatalf("空 token 应拒绝，实际 %d", code)
	}
}

func TestAuthDebugHeaderHonoredInDevelopment(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-2": "u_2"}}, true)
	code, got := do(t, r, map[string]string{"X-Debug-Token": "dev-token-user-2"})
	if code != http.StatusOK || got != "u_2" {
		t.Fatalf("开发期应接受 X-Debug-Token，实际 %d + %q", code, got)
	}
}

func TestAuthDebugHeaderIgnoredOutsideDevelopment(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-2": "u_2"}}, false)
	code, _ := do(t, r, map[string]string{"X-Debug-Token": "dev-token-user-2"})
	if code != http.StatusUnauthorized {
		t.Fatalf("非开发期必须忽略 X-Debug-Token，实际 %d", code)
	}
}

// 契约（前端改造清单）承诺 X-Debug-Token 可用于设置页运行时切换用户。
// 前端会给每个请求注入 Authorization，所以调试头必须能**覆盖**它——
// 若只在其缺失时生效，该承诺等于永不生效。
func TestAuthDebugHeaderOverridesAuthorizationInDevelopment(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{
		"real": "u_1",
		"dbg":  "u_2",
	}}, true)
	code, got := do(t, r, map[string]string{
		"Authorization": "Bearer real",
		"X-Debug-Token": "dbg",
	})
	if code != http.StatusOK || got != "u_2" {
		t.Fatalf("开发期 X-Debug-Token 应覆盖 Authorization，实际 %d + %q", code, got)
	}
}

// 调试头为空串不算「覆盖」，此时应正常回落到 Authorization，
// 否则前端清空切换开关时会连带把自己踢成未认证。
func TestAuthEmptyDebugHeaderFallsBackToAuthorization(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"real": "u_1"}}, true)
	code, got := do(t, r, map[string]string{
		"Authorization": "Bearer real",
		"X-Debug-Token": "   ",
	})
	if code != http.StatusOK || got != "u_1" {
		t.Fatalf("空白调试头应回落到 Authorization，实际 %d + %q", code, got)
	}
}

// 数据库故障应返回 500，而不是把用户当成未认证。
func TestAuthReturnsServerErrorOnResolverFailure(t *testing.T) {
	r := newTestRouter(failTokens{}, false)
	code, errCode := do(t, r, map[string]string{"Authorization": "Bearer whatever"})
	if code != http.StatusInternalServerError || errCode != "INTERNAL_ERROR" {
		t.Fatalf("依赖故障应返回 500 + INTERNAL_ERROR，实际 %d + %q", code, errCode)
	}
}
