package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/models"
)

// 这条是整个前端接入能否工作的前提：预检请求**不携带 Authorization**
// （浏览器规范如此），所以它必须能穿过鉴权拿到 204 + CORS 头。若 CORS 被挂在
// 鉴权之后，预检会先被 401 挡下，浏览器就永远不会发出真实请求 —— 而报错只会
// 提 CORS，让人以为是后端没配 CORS 头，实际是中间件顺序错了。
func TestPreflightBypassesAuthAndReturnsCORSHeaders(t *testing.T) {
	r := NewRouter(config.Config{Env: "development"}, &Handler{
		Users:  fakeUsers{user: map[string]models.User{}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
	})

	req := httptest.NewRequest(http.MethodOptions, "/api/v1/me/preferences", nil)
	req.Header.Set("Origin", "http://localhost:51234")
	req.Header.Set("Access-Control-Request-Method", "PUT")
	req.Header.Set("Access-Control-Request-Headers", "authorization,content-type")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("预检应返回 204；实际 %d。若为 401 说明 CORS 被挂在了 Auth 之后",
			w.Code)
	}
	if got := w.Header().Get("Access-Control-Allow-Origin"); got == "" {
		t.Fatal("预检响应缺少 Access-Control-Allow-Origin，浏览器会拦下真实请求")
	}
}

// 真实请求（带 Origin）的响应也要带 CORS 头，否则浏览器拿到响应也会丢弃。
func TestActualRequestCarriesCORSHeader(t *testing.T) {
	r := testRouter(t)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	req.Header.Set("Origin", "http://localhost:51234")
	req.Header.Set("Authorization", "Bearer dev-token-user-1")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("带 Origin 的真实请求应成功，实际 %d", w.Code)
	}
	if got := w.Header().Get("Access-Control-Allow-Origin"); got == "" {
		t.Fatal("带 Origin 的真实请求响应应含 Access-Control-Allow-Origin")
	}
}

// 生产环境（非 development）零配置时不应放行任意源。
func TestProductionDoesNotAllowAnyOriginByDefault(t *testing.T) {
	r := NewRouter(config.Config{Env: "production"}, &Handler{
		Users:  fakeUsers{user: map[string]models.User{}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	req.Header.Set("Origin", "http://evil.example.com")
	req.Header.Set("Authorization", "Bearer t")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("生产环境不应默认放行任意源，实际 %q", got)
	}
}
