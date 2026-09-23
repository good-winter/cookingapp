package recommend

import (
	"errors"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/models"
)

func recipe(id string, veg bool, crowds, avoidTags []string) models.Recipe {
	return models.Recipe{ID: id, IsVegetarian: veg, Crowds: crowds, AvoidTags: avoidTags}
}

func ids(rs []models.Recipe) []string {
	out := make([]string, len(rs))
	for i, r := range rs {
		out[i] = r.ID
	}
	return out
}

func recipeList(scored []Scored) []models.Recipe {
	out := make([]models.Recipe, len(scored))
	for i, s := range scored {
		out[i] = s.Recipe
	}
	return out
}

func equal(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestRankExcludesNonVegetarianWhenVegetarianMode(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_1", true, nil, nil),
		recipe("r_2", false, nil, nil),
	}
	got := Rank(recipes, models.NewPreferences("vegetarian", nil, nil))
	if len(got) != 1 || got[0].Recipe.ID != "r_1" {
		t.Fatalf("素食模式应只保留 isVegetarian=true，实际 %v", ids(recipeList(got)))
	}
}

func TestRankKeepsNonVegetarianInNormalMode(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_1", true, nil, nil),
		recipe("r_2", false, nil, nil),
	}
	got := Rank(recipes, models.NewPreferences("normal", nil, nil))
	if len(got) != 2 {
		t.Fatalf("正常模式不应过滤荤菜，实际 %v", ids(recipeList(got)))
	}
}

func TestRankExcludesAvoidedIngredients(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_1", true, nil, []string{"cilantro"}),
		recipe("r_2", true, nil, []string{"pork"}),
	}
	got := Rank(recipes, models.NewPreferences("normal", nil, []string{"cilantro"}))
	if len(got) != 1 || got[0].Recipe.ID != "r_2" {
		t.Fatalf("应剔除含香菜（忌口）的菜谱，实际 %v", ids(recipeList(got)))
	}
}

func TestRankOrdersByCrowdMatchThenID(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_3", true, []string{"fitness"}, nil),
		recipe("r_1", true, []string{"fitness", "pregnant"}, nil),
		recipe("r_2", true, []string{"fitness"}, nil),
	}
	got := ids(recipeList(Rank(recipes,
		models.NewPreferences("normal", []string{"fitness", "pregnant"}, nil))))
	want := []string{"r_1", "r_2", "r_3"}
	if !equal(got, want) {
		t.Fatalf("命中越多越靠前、同分按 id 升序；期望 %v，实际 %v", want, got)
	}
}

func TestRankDoesNotMutateInput(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_2", true, nil, nil),
		recipe("r_1", true, nil, nil),
	}
	Rank(recipes, models.NewPreferences("normal", nil, nil))
	if recipes[0].ID != "r_2" || recipes[1].ID != "r_1" {
		t.Fatal("Rank 不应修改传入的切片顺序")
	}
}

func TestRankToleratesNilSlices(t *testing.T) {
	recipes := []models.Recipe{recipe("r_1", true, nil, nil)}
	got := Rank(recipes, models.NewPreferences("normal", nil, nil))
	if len(got) != 1 {
		t.Fatalf("nil 标签不应导致 panic 或误过滤，实际 %d 条", len(got))
	}
}

func TestPageWalksAllItemsExactlyOnce(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_1", true, []string{"fitness", "pregnant"}, nil),
		recipe("r_2", true, []string{"fitness"}, nil),
		recipe("r_3", true, []string{"fitness"}, nil),
		recipe("r_4", true, nil, nil),
		recipe("r_5", true, nil, nil),
	}
	prefs := models.NewPreferences("normal", []string{"fitness"}, nil)
	ranked := Rank(recipes, prefs)

	seen := []string{}
	var cursor *string
	for i := 0; i < 10; i++ { // 上限 10 次，防御死循环
		cur := ""
		if cursor != nil {
			cur = *cursor
		}
		items, next, err := Page(ranked, 2, cur, prefs)
		if err != nil {
			t.Fatalf("分页出错: %v", err)
		}
		seen = append(seen, ids(items)...)
		if next == nil {
			break
		}
		cursor = next
	}
	if !equal(seen, ids(recipeList(ranked))) {
		t.Fatalf("翻页应不重不漏地走完全部；期望 %v，实际 %v",
			ids(recipeList(ranked)), seen)
	}
}

func TestPageReturnsNilCursorOnLastPage(t *testing.T) {
	recipes := []models.Recipe{recipe("r_1", true, nil, nil), recipe("r_2", true, nil, nil)}
	prefs := models.NewPreferences("normal", nil, nil)
	ranked := Rank(recipes, prefs)

	_, next, err := Page(ranked, 10, "", prefs)
	if err != nil {
		t.Fatalf("分页出错: %v", err)
	}
	if next != nil {
		t.Fatalf("一次取完时 nextCursor 应为 nil，实际 %q", *next)
	}
}

func TestPageRejectsMalformedCursor(t *testing.T) {
	prefs := models.NewPreferences("normal", nil, nil)
	if _, _, err := Page(nil, 2, "这不是合法游标", prefs); !errors.Is(err, ErrInvalidCursor) {
		t.Fatalf("非法游标应返回 ErrInvalidCursor，实际 %v", err)
	}
}

func TestPageClampsLimit(t *testing.T) {
	recipes := make([]models.Recipe, 0, MaxLimit+10)
	for i := 0; i < MaxLimit+10; i++ {
		recipes = append(recipes, recipe(string(rune('a'+i%26))+string(rune('0'+i/26)), true, nil, nil))
	}
	prefs := models.NewPreferences("normal", nil, nil)
	ranked := Rank(recipes, prefs)

	items, _, err := Page(ranked, 1000, "", prefs)
	if err != nil {
		t.Fatalf("分页出错: %v", err)
	}
	if len(items) != MaxLimit {
		t.Fatalf("limit 应被钳制到 %d，实际返回 %d 条", MaxLimit, len(items))
	}
}

// 契约（接口 2 / 接口 4）要求：偏好变更后携带旧游标必须被拒，而不是
// 顺着新排序继续翻出一份错乱的序列。这条用例固定该行为。
func TestPageRejectsCursorIssuedUnderAnotherPreference(t *testing.T) {
	recipes := []models.Recipe{
		recipe("r_1", true, nil, nil),
		recipe("r_2", true, []string{"pregnant"}, nil),
		recipe("r_3", true, nil, nil),
	}

	before := models.NewPreferences("normal", nil, nil)
	_, cursor, err := Page(Rank(recipes, before), 1, "", before)
	if err != nil {
		t.Fatalf("签发游标失败: %v", err)
	}
	if cursor == nil {
		t.Fatal("第一页应带 nextCursor")
	}

	after := models.NewPreferences("normal", []string{"pregnant"}, nil)
	_, _, err = Page(Rank(recipes, after), 1, *cursor, after)
	if !errors.Is(err, ErrStaleCursor) {
		t.Fatalf("偏好已变更，旧游标应返回 ErrStaleCursor，实际 %v", err)
	}
}

// 偏好没变时，游标必须照常可用——否则每次翻页都要重头拉，分页就白做了。
func TestPageAcceptsCursorUnderUnchangedPreference(t *testing.T) {
	recipes := []models.Recipe{recipe("r_1", true, nil, nil), recipe("r_2", true, nil, nil)}
	prefs := models.NewPreferences("normal", []string{"fitness"}, nil)
	ranked := Rank(recipes, prefs)

	_, cursor, err := Page(ranked, 1, "", prefs)
	if err != nil || cursor == nil {
		t.Fatalf("签发游标失败: err=%v cursor=%v", err, cursor)
	}
	items, _, err := Page(ranked, 1, *cursor, prefs)
	if err != nil {
		t.Fatalf("同一份偏好下旧游标应可用，实际 %v", err)
	}
	if len(items) != 1 || items[0].ID != "r_2" {
		t.Fatalf("第二页应为 r_2，实际 %v", ids(items))
	}
}

// 指纹只关心语义：前端换个顺序提交同一组偏好，游标不该被判失效。
func TestPreferencesFingerprintIgnoresOrder(t *testing.T) {
	a := PreferencesFingerprint(models.NewPreferences("normal",
		[]string{"fitness", "pregnant"}, []string{"pork", "seafood"}))
	b := PreferencesFingerprint(models.NewPreferences("normal",
		[]string{"pregnant", "fitness"}, []string{"seafood", "pork"}))
	if a != b {
		t.Fatalf("同一组偏好的不同顺序应得到相同指纹: %q vs %q", a, b)
	}
}

// nil 与空切片都是「没选」，指纹必须一致。
func TestPreferencesFingerprintTreatsNilAsEmpty(t *testing.T) {
	nilPrefs := PreferencesFingerprint(models.Preferences{DietMode: "normal"})
	emptyPrefs := PreferencesFingerprint(models.NewPreferences("normal", nil, nil))
	if nilPrefs != emptyPrefs {
		t.Fatalf("nil 与空切片应得到相同指纹: %q vs %q", nilPrefs, emptyPrefs)
	}
}

// 指纹必须能区分语义不同的偏好，否则失效检测形同虚设。
func TestPreferencesFingerprintDistinguishesPreferences(t *testing.T) {
	base := models.NewPreferences("normal", []string{"fitness"}, nil)
	distinct := []models.Preferences{
		models.NewPreferences("vegetarian", []string{"fitness"}, nil),
		models.NewPreferences("normal", []string{"pregnant"}, nil),
		models.NewPreferences("normal", []string{"fitness"}, []string{"pork"}),
		models.NewPreferences("normal", nil, nil),
	}
	seen := map[string]models.Preferences{
		PreferencesFingerprint(base): base,
	}
	for _, p := range distinct {
		fp := PreferencesFingerprint(p)
		if prev, dup := seen[fp]; dup {
			t.Fatalf("指纹碰撞：%+v 与 %+v 得到同一指纹 %q", prev, p, fp)
		}
		seen[fp] = p
	}
}

// 指纹函数不得改动调用方的切片——Rank 有同样的约束。
func TestPreferencesFingerprintDoesNotMutateInput(t *testing.T) {
	crowds := []string{"pregnant", "fitness"}
	PreferencesFingerprint(models.NewPreferences("normal", crowds, nil))
	if crowds[0] != "pregnant" || crowds[1] != "fitness" {
		t.Fatalf("不应改动入参顺序，实际 %v", crowds)
	}
}
