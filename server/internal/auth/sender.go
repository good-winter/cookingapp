// Package auth 负责短信验证码的发送侧。
package auth

import (
	"context"
	"errors"
	"log"

	"github.com/good-winter/cookingapp/server/internal/config"
)

// Sender 是短信发送方。
//
// 抽成接口是为了让「开发期不真发短信」与「将来接阿里云/腾讯云」只差一个实现，
// handler 侧一行都不用动。
type Sender interface {
	Send(ctx context.Context, phone, code string) error
}

// DevSender 只把验证码打进服务端日志，不真发短信。
type DevSender struct{}

func (DevSender) Send(_ context.Context, phone, code string) error {
	// 开发期除了响应里的 devCode，这里是唯一能看到验证码的地方。
	log.Printf("[DEV] 短信验证码 → %s: %s", phone, code)
	return nil
}

// NewSender 按环境选择发送方实现。
//
// 非 development 直接报错让服务起不来，而不是退回 DevSender ——
// 退回的话生产环境的验证码只会写进日志、用户永远收不到，而接口还返回成功。
// 这种失败必须在启动时就炸出来，不能等用户点了「获取验证码」才发现。
func NewSender(cfg config.Config) (Sender, error) {
	if cfg.IsDevelopment() {
		return DevSender{}, nil
	}
	return nil, errors.New(
		"非开发环境尚未接入短信服务商：请实现 auth.Sender 并在 NewSender 中返回它")
}
