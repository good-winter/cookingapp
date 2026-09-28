package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func corsRouter(allowed []string, allowAny bool) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(CORS(allowed, allowAny))
	r.GET("/probe", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) })
	r.PUT("/probe", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) })
	return r
}

// doCORS 发一个带（或不带）Origin 的请求。
func doCORS(r *gin.Engine, method, origin string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, "/probe", nil)
	if origin != "" {
		req.Header.Set("Origin", origin)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestCORSAllowAnyEmitsWildcard(t *testing.T) {
	w := doCORS(corsRouter(nil, true), http.MethodGet, "http://localhost:51234")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("开发期应放行任意源，期望 *，实际 %q", got)
	}
}

// 预检要能拿到 204，且响应里带上允许的方法与头。
func TestCORSPreflightReturnsNoContent(t *testing.T) {
	w := doCORS(corsRouter(nil, true), http.MethodOptions, "http://localhost:51234")
	if w.Code != http.StatusNoContent {
		t.Fatalf("预检期望 204，实际 %d", w.Code)
	}
	if !strings.Contains(w.Header().Get("Access-Control-Allow-Methods"), "PUT") {
		t.Errorf("Allow-Methods 应含 PUT，实际 %q",
			w.Header().Get("Access-Control-Allow-Methods"))
	}
}

// 前端每个请求都带 Authorization，PUT 还带 Content-Type；两者都会触发预检，
// 所以这三个头必须在允许列表里，否则浏览器会拦下真实请求。
func TestCORSAllowsTheHeadersFrontendActuallySends(t *testing.T) {
	w := doCORS(corsRouter(nil, true), http.MethodPut, "http://localhost:1234")
	allow := strings.ToLower(w.Header().Get("Access-Control-Allow-Headers"))
	for _, h := range []string{"authorization", "content-type", "x-debug-token"} {
		if !strings.Contains(allow, h) {
			t.Errorf("Allow-Headers 缺少 %s，实际 %q", h, allow)
		}
	}
}

// 非浏览器请求（curl、服务间调用）没有 Origin，不该被加上 CORS 头。
func TestCORSWithoutOriginEmitsNoAllowOrigin(t *testing.T) {
	w := doCORS(corsRouter(nil, true), http.MethodGet, "")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("无 Origin 时不应加 Allow-Origin，实际 %q", got)
	}
	if w.Code != http.StatusOK {
		t.Fatalf("无 Origin 的正常请求应照常通过，实际 %d", w.Code)
	}
}

func TestCORSAllowlistEchoesMatchingOrigin(t *testing.T) {
	r := corsRouter([]string{"http://localhost:3000"}, false)

	w := doCORS(r, http.MethodGet, "http://localhost:3000")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:3000" {
		t.Fatalf("白名单命中的源应被回显，实际 %q", got)
	}
	// 回显式响应随 Origin 变化，必须声明 Vary，否则中间缓存会串源。
	if !strings.Contains(w.Header().Get("Vary"), "Origin") {
		t.Errorf("回显 Origin 时必须带 Vary: Origin，实际 %q", w.Header().Get("Vary"))
	}
}

func TestCORSAllowlistRejectsOtherOrigins(t *testing.T) {
	w := doCORS(corsRouter([]string{"http://localhost:3000"}, false),
		http.MethodGet, "http://evil.example.com")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("白名单外的源不应放行，实际 %q", got)
	}
}

// 生产环境默认零配置即不加任何 CORS 头 —— 要对外开放必须显式配白名单。
func TestCORSDisabledWhenNoOriginsAndNotAllowAny(t *testing.T) {
	w := doCORS(corsRouter(nil, false), http.MethodGet, "http://localhost:51888")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("未配置时应完全不加 CORS 头，实际 %q", got)
	}
}

// 允许列表的匹配应忽略大小写与两侧空白，避免因为手写配置里的空格而失效。
func TestCORSAllowlistToleratesWhitespaceAndCase(t *testing.T) {
	w := doCORS(corsRouter([]string{" HTTP://LOCALHOST:3000 "}, false),
		http.MethodGet, "http://localhost:3000")
	if got := w.Header().Get("Access-Control-Allow-Origin"); got == "" {
		t.Fatal("应容忍配置项两侧空白与大小写差异")
	}
}
