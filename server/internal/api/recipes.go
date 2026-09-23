package api

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/recommend"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type recommendResponse struct {
	Items      []models.Recipe `json:"items"`
	NextCursor *string         `json:"nextCursor"`
}

// GetRecommend 按当前用户的服务端偏好计算推荐。
// 请求不携带任何偏好参数 —— 偏好已存在服务端，传了也会被忽略。
func (h *Handler) GetRecommend(c *gin.Context) {
	limit := recommend.DefaultLimit
	if raw := c.Query("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 {
			httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
				"limit 必须是正整数", map[string]any{"limit": raw})
			return
		}
		limit = parsed
	}

	ctx := c.Request.Context()
	userID := c.GetString(middleware.ContextUserID)

	prefs, err := h.Users.GetPreferences(ctx, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	recipes, err := h.Recipes.ListRecipes(ctx)
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	ranked := recommend.Rank(recipes, prefs)

	// prefs 一并传入：游标绑定了签发它的那份偏好，偏好变更后旧游标会被拒。
	items, nextCursor, err := recommend.Page(ranked, limit, c.Query("cursor"), prefs)
	if errors.Is(err, recommend.ErrStaleCursor) {
		// 契约接口 2/4：偏好变更后携带过期游标必须回 400，由前端丢弃后重拉。
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"游标已失效（偏好已变更），请丢弃后重新请求", nil)
		return
	}
	if errors.Is(err, recommend.ErrInvalidCursor) {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"游标非法，请丢弃后重新请求", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, recommendResponse{Items: items, NextCursor: nextCursor})
}
