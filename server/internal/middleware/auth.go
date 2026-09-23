package middleware

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/store"
)

// ContextUserID 是注入到 gin.Context 的当前用户 ID 的键。
const ContextUserID = "userID"

// Auth 解析 token 并注入当前用户 ID。
//
// allowDebugHeader 为 true 时（即 APP_ENV=development）X-Debug-Token 会**覆盖**
// Authorization，用于在设置页里运行时切换用户而不必重编译——这是契约对前端的承诺。
//
// 之所以必须是「覆盖」而不是「Authorization 缺失时的替代」：前端会装一个给每个
// 请求注入 Authorization 的拦截器，永远不会有缺失的时候，调试头若只在缺失时生效
// 就等于永不生效。生产环境下 allowDebugHeader 恒为 false，不存在被顶替的风险。
func Auth(tokens store.TokenStore, allowDebugHeader bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := bearerToken(c.GetHeader("Authorization"))
		if allowDebugHeader {
			if debug := strings.TrimSpace(c.GetHeader("X-Debug-Token")); debug != "" {
				token = debug
			}
		}
		if token == "" {
			httputil.Abort(c, http.StatusUnauthorized, httputil.CodeUnauthorized,
				"缺少访问令牌", nil)
			return
		}

		userID, err := tokens.UserIDByToken(c.Request.Context(), token)
		if err != nil {
			// 只有「查不到」才算未认证；依赖故障是服务端错误，
			// 把后者报成 401 会让前端误以为该重新登录。
			if !errors.Is(err, store.ErrNotFound) {
				httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
					"服务器内部错误", nil)
				return
			}
			httputil.Abort(c, http.StatusUnauthorized, httputil.CodeUnauthorized,
				"访问令牌无效", nil)
			return
		}

		c.Set(ContextUserID, userID)
		c.Next()
	}
}

// bearerToken 从 Authorization 头取出 token，方案名大小写不敏感。
// 无 token 时返回空串，调用方据此拒绝。
func bearerToken(header string) string {
	const prefix = "Bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return ""
	}
	return strings.TrimSpace(header[len(prefix):])
}
