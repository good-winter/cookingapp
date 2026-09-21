package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type fakeOptions struct{ opts models.PreferenceOptions }

func (f fakeOptions) Options(_ context.Context) (models.PreferenceOptions, error) {
	return f.opts, nil
}

func defaultOptions() fakeOptions {
	return fakeOptions{opts: models.PreferenceOptions{
		DietModes:  []models.Option{{Code: "normal", Label: "正常人"}, {Code: "vegetarian", Label: "素食主义"}},
		Crowds:     []models.Option{{Code: "pregnant", Label: "孕妇"}, {Code: "fitness", Label: "健身人群"}},
		AvoidFoods: []models.Option{{Code: "pork", Label: "猪肉"}, {Code: "cilantro", Label: "香菜"}},
	}}
}

func TestGetOptionsReturnsAllThreeDictionaries(t *testing.T) {
	r := testRouterWith(&Handler{
		Tokens:  fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: defaultOptions(),
	})

	w := getWithToken(t, r, "/api/v1/preferences/options", "t")
	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", w.Code, w.Body.String())
	}

	var got models.PreferenceOptions
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("响应不是合法 PreferenceOptions: %v", err)
	}
	if len(got.DietModes) != 2 {
		t.Errorf("dietModes 应为 2 项，实际 %+v", got.DietModes)
	}
	if len(got.Crowds) != 2 || got.Crowds[0].Label != "孕妇" {
		t.Errorf("crowds 不符: %+v", got.Crowds)
	}
	if len(got.AvoidFoods) != 2 || got.AvoidFoods[0].Code != "pork" {
		t.Errorf("avoidFoods 不符: %+v", got.AvoidFoods)
	}
}

// 选项字典同样要满足「空数组不是 null」——避免前端拿到 null 后遍历报错。
func TestGetOptionsEmitsEmptyArraysNotNull(t *testing.T) {
	r := testRouterWith(&Handler{
		Tokens:  fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: fakeOptions{opts: models.PreferenceOptions{}},
	})

	w := getWithToken(t, r, "/api/v1/preferences/options", "t")
	body := w.Body.String()
	for _, key := range []string{`"dietModes":[]`, `"crowds":[]`, `"avoidFoods":[]`} {
		if !contains(body, key) {
			t.Errorf("缺少 %s，实际 body=%s", key, body)
		}
	}
}

func TestGetOptionsRequiresAuth(t *testing.T) {
	// 契约把「验证网络层连通性」的最简调用定为本接口，但它仍必须鉴权。
	r := testRouterWith(&Handler{
		Tokens:  fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: defaultOptions(),
	})
	req := httptest.NewRequest(http.MethodGet, "/api/v1/preferences/options", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未带 token 应返回 401，实际 %d", w.Code)
	}
}
