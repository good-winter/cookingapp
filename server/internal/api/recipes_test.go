package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type fakeRecipes struct{ recipes []models.Recipe }

func (f fakeRecipes) ListRecipes(_ context.Context) ([]models.Recipe, error) {
	return f.recipes, nil
}

func newRecipesRouter() *gin.Engine {
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {ID: "u_1",
				Preferences: models.NewPreferences("normal", []string{"fitness"}, nil)},
		}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
		Recipes: fakeRecipes{recipes: []models.Recipe{
			{ID: "r_1", Name: "白灼西兰花", IsVegetarian: true,
				Crowds: []string{"fitness"}, AvoidTags: []string{}},
			{ID: "r_2", Name: "红烧肉", IsVegetarian: false,
				Crowds: []string{}, AvoidTags: []string{"pork"}},
			{ID: "r_3", Name: "番茄炒蛋", IsVegetarian: true,
				Crowds: []string{}, AvoidTags: []string{}},
		}},
	})
}

func getRecommend(t *testing.T, query string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/recipes/recommend"+query, nil)
	req.Header.Set("Authorization", "Bearer t")
	w := httptest.NewRecorder()
	newRecipesRouter().ServeHTTP(w, req)
	return w.Code, w.Body.String()
}

func TestRecommendReturnsRankedItems(t *testing.T) {
	code, body := getRecommend(t, "")
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", code, body)
	}

	var got struct {
		Items []models.Recipe `json:"items"`
	}
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("响应不是合法分页结构: %v", err)
	}
	if len(got.Items) != 3 {
		t.Fatalf("应返回 3 条，实际 %d", len(got.Items))
	}
	// 命中 fitness 的 r_1 排最前；其余同分按 id 升序。
	if got.Items[0].ID != "r_1" || got.Items[1].ID != "r_2" || got.Items[2].ID != "r_3" {
		t.Fatalf("排序不符，实际 %v", []string{
			got.Items[0].ID, got.Items[1].ID, got.Items[2].ID})
	}
}

func TestRecommendNextCursorIsNullWhenExhausted(t *testing.T) {
	_, body := getRecommend(t, "")
	if !contains(body, `"nextCursor":null`) {
		t.Fatalf("没有下一页时 nextCursor 必须是 null，实际 body=%s", body)
	}
}

func TestRecommendPaginates(t *testing.T) {
	code, body := getRecommend(t, "?limit=1")
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d", code)
	}

	var first struct {
		Items      []models.Recipe `json:"items"`
		NextCursor *string         `json:"nextCursor"`
	}
	if err := json.Unmarshal([]byte(body), &first); err != nil {
		t.Fatalf("解析失败: %v", err)
	}
	if len(first.Items) != 1 || first.NextCursor == nil {
		t.Fatalf("期望 1 条且带 nextCursor，实际 %+v", first)
	}

	code2, body2 := getRecommend(t, "?limit=1&cursor="+*first.NextCursor)
	if code2 != http.StatusOK {
		t.Fatalf("第二页期望 200，实际 %d，body=%s", code2, body2)
	}
	var second struct {
		Items []models.Recipe `json:"items"`
	}
	if err := json.Unmarshal([]byte(body2), &second); err != nil {
		t.Fatalf("解析第二页失败: %v", err)
	}
	if len(second.Items) != 1 || second.Items[0].ID == first.Items[0].ID {
		t.Fatalf("第二页应返回不同菜谱，实际 %+v", second.Items)
	}
}

func TestRecommendRejectsBadLimit(t *testing.T) {
	for _, q := range []string{"?limit=abc", "?limit=0", "?limit=-3"} {
		code, body := getRecommend(t, q)
		if code != http.StatusBadRequest || !contains(body, "INVALID_PARAMETER") {
			t.Fatalf("%s 应返回 400 INVALID_PARAMETER，实际 %d %s", q, code, body)
		}
	}
}

func TestRecommendRejectsBadCursor(t *testing.T) {
	code, body := getRecommend(t, "?cursor=这不是游标")
	if code != http.StatusBadRequest || !contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法游标应返回 400，实际 %d %s", code, body)
	}
}

func TestRecommendRequiresAuth(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/recipes/recommend", nil)
	w := httptest.NewRecorder()
	newRecipesRouter().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未带 token 应返回 401，实际 %d", w.Code)
	}
}

// 偏好为素食时，荤菜应被剔除 —— 这条走完整 handler 链路，验证 store 的偏好确实被用上。
func TestRecommendAppliesServerSidePreferences(t *testing.T) {
	r := testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {ID: "u_1",
				Preferences: models.NewPreferences("vegetarian", nil, nil)},
		}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
		Recipes: fakeRecipes{recipes: []models.Recipe{
			{ID: "r_1", Name: "番茄炒蛋", IsVegetarian: true, Crowds: []string{}, AvoidTags: []string{}},
			{ID: "r_2", Name: "红烧肉", IsVegetarian: false, Crowds: []string{}, AvoidTags: []string{}},
		}},
	})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/recipes/recommend", nil)
	req.Header.Set("Authorization", "Bearer t")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d", w.Code)
	}
	var got struct {
		Items []models.Recipe `json:"items"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("解析失败: %v", err)
	}
	if len(got.Items) != 1 || got.Items[0].ID != "r_1" {
		t.Fatalf("素食模式应只返回素食菜谱，实际 %+v", got.Items)
	}
}
