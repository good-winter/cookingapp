package api

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/store"
)

func (h *Handler) GetMe(c *gin.Context) {
	userID := c.GetString(middleware.ContextUserID)

	user, err := h.Users.GetUser(c.Request.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, user)
}
