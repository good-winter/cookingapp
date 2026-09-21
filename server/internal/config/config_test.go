package config

import "testing"

func TestLoadRequiresDSN(t *testing.T) {
	t.Setenv("APP_DSN", "")
	if _, err := Load(); err == nil {
		t.Fatal("APP_DSN 缺失时应当返回错误，实际返回 nil")
	}
}

func TestLoadDefaults(t *testing.T) {
	t.Setenv("APP_DSN", "user:pass@tcp(127.0.0.1:3306)/cookingapp")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("不应报错: %v", err)
	}
	if cfg.Addr != ":8080" {
		t.Errorf("Addr 默认值应为 :8080，实际 %q", cfg.Addr)
	}
	if cfg.Env != "development" {
		t.Errorf("Env 默认值应为 development，实际 %q", cfg.Env)
	}
	if !cfg.AutoMigrate {
		t.Error("AutoMigrate 默认值应为 true")
	}
}
