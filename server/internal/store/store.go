package store

import (
	"context"
	"errors"
	"time"

	"github.com/good-winter/cookingapp/server/internal/models"
)

// ErrNotFound 表示请求的资源不存在。handler 据此映射为 404。
var ErrNotFound = errors.New("资源不存在")

// ErrDuplicate 表示唯一约束冲突（目前只有 users.phone）。
// 并发注册同一号码时，后到的那个写会拿到它 —— 调用方应改为复用已存在的行，
// 而不是把一个 500 抛给用户。
var ErrDuplicate = errors.New("资源已存在")

type UserStore interface {
	GetUser(ctx context.Context, userID string) (models.User, error)
	GetPreferences(ctx context.Context, userID string) (models.Preferences, error)
	UpdatePreferences(ctx context.Context, userID string, prefs models.Preferences) error
}

type TokenStore interface {
	UserIDByToken(ctx context.Context, token string) (string, error)
	// CreateToken 签发一个新的登录 token。
	CreateToken(ctx context.Context, token, userID string) error
}

// AuthStore 是手机号登录的存储。
//
// 单独一个接口而不是并进 UserStore：UserStore 对应契约里「用户与偏好」那组
// 接口，验证码是登录流程自己的状态，混在一起会让 UserStore 的语义变糊。
type AuthStore interface {
	// LatestSmsCode 取该手机号最近一条验证码（不论是否已消费），
	// 供限流与校验共用。无记录返回 ErrNotFound。
	LatestSmsCode(ctx context.Context, phone string) (models.SmsCode, error)
	CreateSmsCode(ctx context.Context, phone, code string, expiresAt time.Time) error
	// ConsumeSmsCode 以「仅当尚未消费」为条件标记已用，返回 ErrNotFound
	// 表示已被别的请求抢先消费 —— 这样验证码的「一次性」不依赖调用方加锁。
	ConsumeSmsCode(ctx context.Context, id int64, at time.Time) error
	// IncreaseSmsAttempts 把失败计数加一。
	// 由 SQL 做自增而不是由调用方读出来再加：并发猜码时读-改-写会互相覆盖，
	// 让「最多试 5 次」实际上变成「最多试 5 轮」。
	IncreaseSmsAttempts(ctx context.Context, id int64) error
	// CountSmsCodesSince 统计该手机号自 since 起签发过多少条，用于当日上限。
	CountSmsCodesSince(ctx context.Context, phone string, since time.Time) (int, error)

	// UserIDByPhone 无此号码时返回 ErrNotFound。
	UserIDByPhone(ctx context.Context, phone string) (string, error)
	// CreateUserWithPhone 建用户并写入默认偏好；号码已存在时返回 ErrDuplicate。
	CreateUserWithPhone(ctx context.Context, u models.User, phone string) error
}

type OptionsStore interface {
	Options(ctx context.Context) (models.PreferenceOptions, error)
}

type RecipeStore interface {
	ListRecipes(ctx context.Context) ([]models.Recipe, error)
}
