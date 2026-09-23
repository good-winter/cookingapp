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

// 重复值在语义上仍是同一个集合成员。此前会逐条 INSERT，撞上
// user_preference_crowds 的主键 (user_id, crowd) 让整个 PUT 冒成 500。
// 响应必须回显去重后的结果，否则前端本地状态与库里存的不一致。
func TestPutPreferencesDeduplicatesValues(t *testing.T) {
	code, body := putPrefs(t,
		`{"dietMode":"normal","crowds":["fitness","fitness","pregnant"],"avoidFoods":["pork","pork"]}`)
	if code != http.StatusOK {
		t.Fatalf("重复值应被接受并去重，期望 200，实际 %d %s", code, body)
	}
	if !contains(body, `"crowds":["fitness","pregnant"]`) {
		t.Errorf("crowds 应去重并保留首次出现顺序，实际 %s", body)
	}
	if !contains(body, `"avoidFoods":["pork"]`) {
		t.Errorf("avoidFoods 应去重，实际 %s", body)
	}
}

// 全部是重复值时也不能退化成空集合或报错。
func TestPutPreferencesAcceptsAllDuplicates(t *testing.T) {
	code, body := putPrefs(t,
		`{"dietMode":"normal","crowds":["fitness","fitness"],"avoidFoods":[]}`)
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d %s", code, body)
	}
	if !contains(body, `"crowds":["fitness"]`) {
		t.Errorf("应只保留一个 fitness，实际 %s", body)
	}
}

// 超大请求体应被明确拒绝，而不是被一路读完。
func TestPutPreferencesRejectsOversizedBody(t *testing.T) {
	huge := `{"dietMode":"normal","crowds":[],"avoidFoods":[],"note":"` +
		strings.Repeat("x", maxPreferencesBodyBytes+1) + `"}`
	code, body := putPrefs(t, huge)
	if code != http.StatusBadRequest || !contains(body, "INVALID_PARAMETER") {
		t.Fatalf("超大请求体应返回 400 INVALID_PARAMETER，实际 %d %s", code, body)
	}
	if !contains(body, "请求体过大") {
		t.Errorf("应提示请求体过大，而不是报成 JSON 格式错误；实际 %s", body)
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
