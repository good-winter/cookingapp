package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
)

func (h *Handler) GetOptions(c *gin.Context) {
	opts, err := h.Options.Options(c.Request.Context())
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}
	c.JSON(http.StatusOK, opts.Normalized())
}
