package api

import (
	"time"

	"github.com/good-winter/cookingapp/server/internal/auth"
	"github.com/good-winter/cookingapp/server/internal/store"
)

// Handler 持有各领域 store 的接口，便于测试时注入假实现。
type Handler struct {
	Users   store.UserStore
	Tokens  store.TokenStore
	Options store.OptionsStore
	Recipes store.RecipeStore
	Auth    store.AuthStore

	SMS SMSAuth
}

// SMSAuth 是登录接口需要的、与存储无关的那部分配置。
//
// 不把整个 config.Config 塞进 Handler：Handler 只该拿到它用得上的东西。
// 否则测试里为了一个 DevCode 就得拼一份完整 Config，还会多出
// 「handler 手里的 Env 与 router 手里的 Env 不是同一个」这种双真相源问题。
type SMSAuth struct {
	Sender  auth.Sender
	CodeTTL time.Duration
	// DevCode 非空时，发送接口以它作为验证码并在响应里回显。
	// 只在 development 下被填充 —— 见 cmd/api/main.go。
	DevCode string
}

// ttl 兜底。零值会让验证码的过期时间等于签发时间，表现为每个码一签发就过期、
// 用户怎么输都被告知「验证码已过期」，且看不出是配置问题。
func (s SMSAuth) ttl() time.Duration {
	if s.CodeTTL <= 0 {
		return 5 * time.Minute
	}
	return s.CodeTTL
}
