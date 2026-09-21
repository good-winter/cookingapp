package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/models"
)

func newPrefsRouter() *gin.Engine {
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {ID: "u_1", Nickname: "美食家", AvatarText: "美",
				Timezone:    "Asia/Shanghai",
				Preferences: models.NewPreferences("normal", nil, nil)},
		}},
		Tokens:  fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: defaultOptions(),
	})
}

func putPrefs(t *testing.T, body string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodPut, "/api/v1/me/preferences", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer t")
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	newPrefsRouter().ServeHTTP(w, req)
	return w.Code, w.Body.String()
}

func TestPutPreferencesAcceptsValidPayload(t *testing.T) {
	code, body := putPrefs(t,
		`{"dietMode":"vegetarian","crowds":["pregnant"],"avoidFoods":["pork"]}`)
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", code, body)
	}

	var got models.Preferences
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("响应不是合法 Preferences: %v", err)
	}
	if got.DietMode != "vegetarian" || len(got.Crowds) != 1 || len(got.AvoidFoods) != 1 {
		t.Errorf("返回的偏好不符: %+v", got)
	}
}

// 返回值必须能让前端直接拿去更新本地状态，所以三个字段都要回来。
func TestPutPreferencesReturnsFullPreferences(t *testing.T) {
	_, body := putPrefs(t, `{"dietMode":"normal","crowds":["fitness"],"avoidFoods":[]}`)
	if !strings.Contains(body, `"dietMode":"normal"`) ||
		!strings.Contains(body, `"crowds":["fitness"]`) ||
		!strings.Contains(body, `"avoidFoods":[]`) {
		t.Fatalf("应返回完整偏好且空数组为 []，实际 %s", body)
	}
}

func TestPutPreferencesRejectsUnknownDietMode(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"吃素","crowds":[],"avoidFoods":[]}`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 dietMode 应返回 400 INVALID_PARAMETER，实际 %d %s", code, body)
	}
}

func TestPutPreferencesRejectsUnknownCrowd(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"normal","crowds":["宇航员"],"avoidFoods":[]}`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 crowd 应返回 400，实际 %d %s", code, body)
	}
	if !strings.Contains(body, "宇航员") {
		t.Errorf("details 里应回显非法值，便于前端定位；实际 %s", body)
	}
}

func TestPutPreferencesRejectsUnknownAvoidFood(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"normal","crowds":[],"avoidFoods":["榴莲"]}`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 avoidFood 应返回 400，实际 %d %s", code, body)
	}
}

// 空数组是合法输入：用户清空全部人群/忌口后保存，必须被接受。
func TestPutPreferencesAcceptsEmptyArrays(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"normal","crowds":[],"avoidFoods":[]}`)
	if code != http.StatusOK {
		t.Fatalf("空数组是合法输入，期望 200，实际 %d %s", code, body)
	}
}

func TestPutPreferencesRejectsMalformedJSON(t *testing.T) {
	code, body := putPrefs(t, `{这不是 JSON`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 JSON 应返回 400，实际 %d %s", code, body)
	}
}

func TestPutPreferencesRequiresAuth(t *testing.T) {
	req := httptest.NewRequest(http.MethodPut, "/api/v1/me/preferences",
		strings.NewReader(`{"dietMode":"normal","crowds":[],"avoidFoods":[]}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	newPrefsRouter().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未带 token 应返回 401，实际 %d", w.Code)
	}
}
