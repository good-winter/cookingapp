package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Addr        string
	DSN         string
	Env         string
	AutoMigrate bool

	// SmsCode 是开发期的固定验证码。**只在 IsDevelopment() 时被使用** ——
	// 生产环境用随机码，这个值会被忽略（见 api.SMSAuth.DevCode 的填充处）。
	SmsCode string
	// SmsCodeTTL 是验证码的有效期。
	SmsCodeTTL time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Addr: getenv("APP_ADDR", ":8080"),
		Env:  getenv("APP_ENV", "development"),
		DSN:  os.Getenv("APP_DSN"),
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

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
