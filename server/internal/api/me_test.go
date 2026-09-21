package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type fakeUsers struct {
	user map[string]models.User
}

func (f fakeUsers) GetUser(_ context.Context, userID string) (models.User, error) {
	u, ok := f.user[userID]
	if !ok {
		return models.User{}, store.ErrNotFound
	}
	return u, nil
}

func (f fakeUsers) GetPreferences(_ context.Context, userID string) (models.Preferences, error) {
	u, ok := f.user[userID]
	if !ok {
		return models.Preferences{}, store.ErrNotFound
	}
	return u.Preferences, nil
}

func (f fakeUsers) UpdatePreferences(_ context.Context, userID string, p models.Preferences) error {
	u, ok := f.user[userID]
	if !ok {
		return store.ErrNotFound
	}
	u.Preferences = p
	f.user[userID] = u
	return nil
}

type fakeTokens struct{ valid map[string]string }

func (f fakeTokens) UserIDByToken(_ context.Context, token string) (string, error) {
	if id, ok := f.valid[token]; ok {
		return id, nil
	}
	return "", store.ErrNotFound
}

func testRouterWith(h *Handler) *gin.Engine {
	return NewRouter(config.Config{Env: "development"}, h)
}

func testRouter(t *testing.T) *gin.Engine {
	t.Helper()
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {
				ID: "u_1", Nickname: "美食家", AvatarText: "美",
				Timezone:    "Asia/Shanghai",
				Preferences: models.NewPreferences("normal", []string{"pregnant"}, nil),
			},
		}},
		Tokens: fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}},
	})
}

func getWithToken(t *testing.T, r *gin.Engine, path, token string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestGetMeReturnsUserWithPreferences(t *testing.T) {
	w := getWithToken(t, testRouter(t), "/api/v1/me", "dev-token-user-1")
	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", w.Code, w.Body.String())
	}

	var got models.User
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("响应不是合法 User: %v", err)
	}
	if got.ID != "u_1" || got.Nickname != "美食家" {
		t.Errorf("用户字段不符: %+v", got)
	}
	if got.Timezone != "Asia/Shanghai" {
		t.Errorf("timezone 不符: %q", got.Timezone)
	}
	if len(got.Preferences.Crowds) != 1 || got.Preferences.Crowds[0] != "pregnant" {
		t.Errorf("偏好不符: %+v", got.Preferences)
	}
}

// 契约要求空数组序列化为 []，不能是 null。
func TestGetMeEmitsEmptyArraysNotNull(t *testing.T) {
	w := getWithToken(t, testRouter(t), "/api/v1/me", "dev-token-user-1")
	if body := w.Body.String(); !strings.Contains(body, `"avoidFoods":[]`) {
		t.Fatalf("空数组必须序列化为 []，实际 body=%s", body)
	}
}

func TestGetMeRequiresAuth(t *testing.T) {
	w := getWithToken(t, testRouter(t), "/api/v1/me", "")
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未带 token 应返回 401，实际 %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "UNAUTHORIZED") {
		t.Fatalf("错误码应为 UNAUTHORIZED，实际 %s", w.Body.String())
	}
}

// 用户已被删除（token 仍有效）时应返回 404，而不是 500。
func TestGetMeReturnsNotFoundWhenUserMissing(t *testing.T) {
	r := testRouterWith(&Handler{
		Users:  fakeUsers{user: map[string]models.User{}},
		Tokens: fakeTokens{valid: map[string]string{"tk": "u_ghost"}},
	})
	w := getWithToken(t, r, "/api/v1/me", "tk")
	if w.Code != http.StatusNotFound {
		t.Fatalf("期望 404，实际 %d，body=%s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), "USER_NOT_FOUND") {
		t.Fatalf("错误码应为 USER_NOT_FOUND，实际 %s", w.Body.String())
	}
}

func TestHealthzNeedsNoAuth(t *testing.T) {
	w := getWithToken(t, testRouter(t), "/healthz", "")
	if w.Code != http.StatusOK {
		t.Fatalf("健康检查不应要求鉴权，实际 %d", w.Code)
	}
}

// 每次请求都应拿到独立的响应，验证 fake 不会被跨请求污染。
func TestGetMeIsRepeatable(t *testing.T) {
	r := testRouter(t)
	for i := 0; i < 3; i++ {
		w := getWithToken(t, r, "/api/v1/me", "dev-token-user-1")
		if w.Code != http.StatusOK {
			t.Fatalf("第 %d 次请求失败: %d", i+1, w.Code)
		}
	}
}
