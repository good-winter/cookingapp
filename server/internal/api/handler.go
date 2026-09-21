package api

import "github.com/good-winter/cookingapp/server/internal/store"

// Handler 持有各领域 store 的接口，便于测试时注入假实现。
type Handler struct {
	Users   store.UserStore
	Tokens  store.TokenStore
	Options store.OptionsStore
	Recipes store.RecipeStore
}
