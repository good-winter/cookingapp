package api

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type preferencesRequest struct {
	DietMode   string   `json:"dietMode"`
	Crowds     []string `json:"crowds"`
	AvoidFoods []string `json:"avoidFoods"`
}

// maxPreferencesBodyBytes 偏好请求体上限。三个数组合计最多几十个短枚举值，
// 正常请求在 1 KiB 以内，64 KiB 是量级上的宽裕值。
const maxPreferencesBodyBytes = 64 << 10

// PutPreferences 是全量替换语义（与 PUT 契约一致）：
// 未提交的旧值会被清除，而不是保留。
func (h *Handler) PutPreferences(c *gin.Context) {
	// 不加限制时 ShouldBindJSON 会一直读到客户端声称的长度为止，
	// 一个超大 body 就能白占住内存。gin 默认不设上限。
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxPreferencesBodyBytes)

	var req preferencesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		// 超限与格式错误的成因不同，分开报，别让调用方去猜。
		// 用 400 INVALID_PARAMETER 而不是新增 413：契约里 413 专指上传图片过大，
		// 为 JSON 请求体另立一组状态码/错误码配对会越过契约。
		var tooLarge *http.MaxBytesError
		if errors.As(err, &tooLarge) {
			httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
				"请求体过大", nil)
			return
		}
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"请求体不是合法 JSON", nil)
		return
	}

	ctx := c.Request.Context()

	dict, err := h.Options.Options(ctx)
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	// 校验取值必须落在字典内。前端下发的选项本就来自同一张字典，
	// 这里是防止越权写入任意值污染推荐结果。
	invalid := map[string]any{}
	if !inOptions(req.DietMode, dict.DietModes) {
		invalid["dietMode"] = req.DietMode
	}
	if bad := unknownValues(req.Crowds, dict.Crowds); len(bad) > 0 {
		invalid["crowds"] = bad
	}
	if bad := unknownValues(req.AvoidFoods, dict.AvoidFoods); len(bad) > 0 {
		invalid["avoidFoods"] = bad
	}
	if len(invalid) > 0 {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"偏好取值不在允许的字典内", map[string]any{"invalid": invalid})
		return
	}

	prefs := models.NewPreferences(req.DietMode, req.Crowds, req.AvoidFoods)
	userID := c.GetString(middleware.ContextUserID)

	if err := h.Users.UpdatePreferences(ctx, userID, prefs); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
			return
		}
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, prefs)
}

func inOptions(code string, opts []models.Option) bool {
	for _, o := range opts {
		if o.Code == code {
			return true
		}
	}
	return false
}

func unknownValues(values []string, opts []models.Option) []string {
	out := []string{}
	for _, v := range values {
		if !inOptions(v, opts) {
			out = append(out, v)
		}
	}
	return out
}
