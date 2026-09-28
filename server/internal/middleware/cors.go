package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// CORS 处理浏览器的跨源请求。
//
// 为什么必须有：前端是 Flutter web，App 与 API 不同源（App 由 flutter run
// 起在 localhost 的随机端口，API 在 127.0.0.1:8080）。且每个请求都带
// Authorization，PUT 还带 Content-Type: application/json —— 两者都会触发
// 预检。没有本中间件时浏览器会在客户端拦掉响应，且报错只提 CORS，不看后端。
//
// 必须挂在鉴权之前：预检请求**不携带 Authorization**（浏览器规范如此），
// 若先过鉴权会被 401 挡下，浏览器就永远不会发出真实请求。因此这里在预检处
// 直接终止。
//
// allowAny 为 true 时放行任意源（开发期默认），用于适配 flutter run 的随机
// 端口。此时用 Allow-Origin: * —— 本服务靠 Bearer 头鉴权、不使用 Cookie，
// 不属于 CORS 的「凭据请求」，所以 * 是安全的。allowed 非空时逐个精确匹配，
// 并回显实际源。两者都空则完全不加 CORS 头（生产环境的默认姿态）。
func CORS(allowed []string, allowAny bool) gin.HandlerFunc {
	enabled := allowAny || len(allowed) > 0

	return func(c *gin.Context) {
		if !enabled {
			c.Next()
			return
		}

		origin := c.GetHeader("Origin")
		switch {
		case origin == "":
			// 非浏览器请求（curl、服务间调用）没有 Origin，无需 CORS 头。
		case allowAny:
			c.Header("Access-Control-Allow-Origin", "*")
		case containsFold(allowed, origin):
			c.Header("Access-Control-Allow-Origin", origin)
			// 精确匹配时响应随 Origin 变化，必须声明，否则中间缓存会串源。
			c.Header("Vary", "Origin")
		default:
			// 不在白名单：不加头，让浏览器自己拦。
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers",
			"Authorization, Content-Type, X-Debug-Token")
		c.Header("Access-Control-Max-Age", "600")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// containsFold 大小写不敏感地匹配源。Origin 里的主机名大小写不敏感，
// 但 scheme 必须小写，这里整体折叠比较够用。
func containsFold(list []string, target string) bool {
	for _, v := range list {
		if strings.EqualFold(strings.TrimSpace(v), target) {
			return true
		}
	}
	return false
}
