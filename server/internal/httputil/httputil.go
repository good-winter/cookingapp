package httputil

import "github.com/gin-gonic/gin"

// 契约中定义的 error.code 全集。
const (
	CodeUnauthorized           = "UNAUTHORIZED"
	CodeForbidden              = "FORBIDDEN"
	CodeUserNotFound           = "USER_NOT_FOUND"
	CodeRecipeNotFound         = "RECIPE_NOT_FOUND"
	CodePostNotFound           = "POST_NOT_FOUND"
	CodeImageNotRecognized     = "IMAGE_NOT_RECOGNIZED"
	CodeImageTooLarge          = "IMAGE_TOO_LARGE"
	CodeUnsupportedImageFormat = "UNSUPPORTED_IMAGE_FORMAT"
	CodeInvalidParameter       = "INVALID_PARAMETER"
	CodeRateLimited            = "RATE_LIMITED"
	CodeInternalError          = "INTERNAL_ERROR"

	// 短信验证码登录（契约补充，见 docs/2026-09-28-auth-login.md）。
	// 刻意不复用 INVALID_PARAMETER：前端要靠这两个码把「码输错了，改一位再试」
	// 与「码过期了，得重新获取」区分开，二者给的引导完全不同。
	CodeSmsCodeInvalid = "SMS_CODE_INVALID"
	CodeSmsCodeExpired = "SMS_CODE_EXPIRED"
)

type ErrorBody struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details"`
}

type errorEnvelope struct {
	Error ErrorBody `json:"error"`
}

// Abort 写出契约约定的错误响应并终止后续 handler。
// details 为 nil 时输出空对象，而不是 null。
func Abort(c *gin.Context, status int, code, message string, details map[string]any) {
	if details == nil {
		details = map[string]any{}
	}
	c.AbortWithStatusJSON(status, errorEnvelope{
		Error: ErrorBody{Code: code, Message: message, Details: details},
	})
}
