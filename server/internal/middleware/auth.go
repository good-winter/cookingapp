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
// allowDebugHeader 为 true 时额外接受 X-Debug-Token，用于开发期在设置页里
// 运行时切换用户而不必重编译。Authorization 头优先，避免调试头意外覆盖真实身份。
func Auth(tokens store.TokenStore, allowDebugHeader bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := bearerToken(c.GetHeader("Authorization"))
		if token == "" && allowDebugHeader {
			token = strings.TrimSpace(c.GetHeader("X-Debug-Token"))
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
