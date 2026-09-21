package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/middleware"
)

func NewRouter(cfg config.Config, h *Handler) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")
	v1.Use(middleware.Auth(h.Tokens, cfg.IsDevelopment()))
	{
		v1.GET("/me", h.GetMe)
		v1.PUT("/me/preferences", h.PutPreferences)

		v1.GET("/preferences/options", h.GetOptions)

		v1.GET("/recipes/recommend", h.GetRecommend)
	}

	return r
}
