package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"github.com/good-winter/cookingapp/server/internal/api"
	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/db"
	"github.com/good-winter/cookingapp/server/internal/store"
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

	handler := &api.Handler{
		Users:   store.NewMySQLUserStore(conn),
		Tokens:  store.NewMySQLUserStore(conn),
		Options: store.NewMySQLOptionsStore(conn),
		Recipes: store.NewMySQLRecipeStore(conn),
	}

	srv := &http.Server{
		Handler: api.NewRouter(cfg, handler),
		// 不设 ReadHeaderTimeout 时，一个只连不发的客户端就能一直占着连接，
		// 攒够数量即拖垮服务（Slowloris）。
		ReadHeaderTimeout: 10 * time.Second,
	}

	// 先同步 bind 再异步 Serve：这样「服务已启动」出口时端口一定已经拿到。
	// 直接在 goroutine 里 ListenAndServe 的话，端口被占用这类失败会与这行
	// 日志抢跑，让一次失败的启动看起来像成功了。
	ln, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		log.Fatalf("监听 %s 失败: %v", cfg.Addr, err)
	}
	log.Printf("服务已启动，监听 %s（env=%s）", cfg.Addr, cfg.Env)

	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.Serve(ln) }()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serveErr:
		// Serve 在收到信号之前返回，说明监听意外中断。
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("服务异常中断: %v", err)
		}
	case <-quit:
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("关闭服务时出错: %v", err)
	}
}
