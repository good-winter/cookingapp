package store

import (
	"context"
	"errors"

	"github.com/good-winter/cookingapp/server/internal/models"
)

// ErrNotFound 表示请求的资源不存在。handler 据此映射为 404。
var ErrNotFound = errors.New("资源不存在")

type UserStore interface {
	GetUser(ctx context.Context, userID string) (models.User, error)
	GetPreferences(ctx context.Context, userID string) (models.Preferences, error)
	UpdatePreferences(ctx context.Context, userID string, prefs models.Preferences) error
}

type TokenStore interface {
	UserIDByToken(ctx context.Context, token string) (string, error)
}

type OptionsStore interface {
	Options(ctx context.Context) (models.PreferenceOptions, error)
}

type RecipeStore interface {
	ListRecipes(ctx context.Context) ([]models.Recipe, error)
}
