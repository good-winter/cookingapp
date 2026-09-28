package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/middleware"
)

func NewRouter(cfg config.Config, h *Handler) *gin.Engine {
	r := gin.New()
	// CORS 挂在鉴权之前：预检请求不带 Authorization，若先过鉴权会被 401 挡下，
	// 浏览器就永远不会发出真实请求。详见 middleware.CORS 的说明。
	r.Use(gin.Recovery(), middleware.CORS(cfg.AllowedOrigins, cfg.AllowAnyOrigin()))
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")

	// 免鉴权：登录用。**必须注册在带 Auth 的子组之外** ——
	// v1.Use(...) 对之后注册的所有路由生效，把这两个放进鉴权组会变成
	// 「要求先登录才能登录」的死循环，而且报错信息完全指不到这里。
	v1.POST("/auth/sms/send", h.PostSmsSend)
	v1.POST("/auth/sms/verify", h.PostSmsVerify)

	authed := v1.Group("")
	authed.Use(middleware.Auth(h.Tokens, cfg.IsDevelopment()))
	{
		authed.GET("/me", h.GetMe)
		authed.PUT("/me/preferences", h.PutPreferences)

		authed.GET("/preferences/options", h.GetOptions)

		authed.GET("/recipes/recommend", h.GetRecommend)
	}

	return r
}
