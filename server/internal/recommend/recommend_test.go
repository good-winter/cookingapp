package recommend

import (
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
	ranked := Rank(recipes, models.NewPreferences("normal", []string{"fitness"}, nil))

	seen := []string{}
	var cursor *string
	for i := 0; i < 10; i++ { // 上限 10 次，防御死循环
		cur := ""
		if cursor != nil {
			cur = *cursor
		}
		items, next, err := Page(ranked, 2, cur)
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
	ranked := Rank(recipes, models.NewPreferences("normal", nil, nil))

	_, next, err := Page(ranked, 10, "")
	if err != nil {
		t.Fatalf("分页出错: %v", err)
	}
	if next != nil {
		t.Fatalf("一次取完时 nextCursor 应为 nil，实际 %q", *next)
	}
}

func TestPageRejectsMalformedCursor(t *testing.T) {
	if _, _, err := Page(nil, 2, "这不是合法游标"); err == nil {
		t.Fatal("非法游标应返回错误")
	}
}

func TestPageClampsLimit(t *testing.T) {
	recipes := make([]models.Recipe, 0, MaxLimit+10)
	for i := 0; i < MaxLimit+10; i++ {
		recipes = append(recipes, recipe(string(rune('a'+i%26))+string(rune('0'+i/26)), true, nil, nil))
	}
	ranked := Rank(recipes, models.NewPreferences("normal", nil, nil))

	items, _, err := Page(ranked, 1000, "")
	if err != nil {
		t.Fatalf("分页出错: %v", err)
	}
	if len(items) != MaxLimit {
		t.Fatalf("limit 应被钳制到 %d，实际返回 %d 条", MaxLimit, len(items))
	}
}
