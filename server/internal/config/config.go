package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Addr        string
	DSN         string
	Env         string
	AutoMigrate bool

	// AllowedOrigins 是 CORS 白名单，来自 APP_ALLOWED_ORIGINS（逗号分隔）。
	AllowedOrigins []string

	// SmsCode 是开发期的固定验证码。**只在 IsDevelopment() 时被使用** ——
	// 生产环境用随机码，这个值会被忽略（见 api.SMSAuth.DevCode 的填充处）。
	SmsCode string
	// SmsCodeTTL 是验证码的有效期。
	SmsCodeTTL time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Addr:           getenv("APP_ADDR", ":8080"),
		Env:            getenv("APP_ENV", "development"),
		DSN:            os.Getenv("APP_DSN"),
		AllowedOrigins: splitList(os.Getenv("APP_ALLOWED_ORIGINS")),
	}

	if cfg.DSN == "" {
		return Config{}, fmt.Errorf("环境变量 APP_DSN 未设置")
	}

	auto, err := strconv.ParseBool(getenv("APP_AUTO_MIGRATE", "true"))
	if err != nil {
		return Config{}, fmt.Errorf("APP_AUTO_MIGRATE 不是合法布尔值: %w", err)
	}
	cfg.AutoMigrate = auto

	cfg.SmsCode = getenv("APP_SMS_CODE", "123456")

	ttl, err := time.ParseDuration(getenv("APP_SMS_CODE_TTL", "5m"))
	if err != nil {
		return Config{}, fmt.Errorf("APP_SMS_CODE_TTL 不是合法时长: %w", err)
	}
	cfg.SmsCodeTTL = ttl

	return cfg, nil
}

// IsDevelopment 用于决定是否启用 X-Debug-Token 等仅开发期可用的行为。
func (c Config) IsDevelopment() bool { return c.Env == "development" }

// AllowAnyOrigin 开发期未显式配置白名单时放行任意源。flutter run 每次给 web
// 应用分配随机端口，写死白名单不现实；生产环境（APP_ENV != development）
// 默认不加任何 CORS 头，要开放必须显式配置 APP_ALLOWED_ORIGINS。
func (c Config) AllowAnyOrigin() bool {
	return len(c.AllowedOrigins) == 0 && c.IsDevelopment()
}

// splitList 解析逗号分隔的列表，去掉空白项；空串返回 nil。
func splitList(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if v := strings.TrimSpace(p); v != "" {
			out = append(out, v)
		}
	}
	return out
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
