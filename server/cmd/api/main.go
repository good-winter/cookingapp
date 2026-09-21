package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/db"
)

func main() {
	_ = godotenv.Load() // .env 不存在时不报错

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("配置加载失败: %v", err)
	}

	ctx := context.Background()
	conn, err := db.Open(ctx, cfg.DSN)
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer conn.Close()

	if cfg.AutoMigrate {
		if err := db.Migrate(ctx, conn); err != nil {
			log.Fatalf("数据库迁移失败: %v", err)
		}
	}

	if !cfg.IsDevelopment() {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	srv := &http.Server{Addr: cfg.Addr, Handler: r}

	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("服务启动失败: %v", err)
		}
	}()
	log.Printf("服务已启动，监听 %s（env=%s）", cfg.Addr, cfg.Env)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("关闭服务时出错: %v", err)
	}
}
