package store

import (
	"context"
	"database/sql"
	"os"
	"testing"

	_ "github.com/go-sql-driver/mysql"
	"github.com/joho/godotenv"

	"github.com/good-winter/cookingapp/server/internal/models"
)

// testDB 连接真实 MySQL。未设置 APP_DSN 时跳过——这样 go test ./... 在没有
// 数据库的机器上也能通过，而本地联调时能真正验证 SQL。
func testDB(t *testing.T) *sql.DB {
	t.Helper()

	_ = godotenv.Load("../../.env")
	dsn := os.Getenv("APP_DSN")
	if dsn == "" {
		t.Skip("APP_DSN 未设置，跳过集成测试")
	}

	db, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatalf("打开数据库失败: %v", err)
	}
	if err := db.Ping(); err != nil {
		db.Close()
		t.Fatalf("连接数据库失败: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestGetUserReturnsSeededUserWithPreferences(t *testing.T) {
	db := testDB(t)
	s := NewMySQLUserStore(db)

	u, err := s.GetUser(context.Background(), "u_2")
	if err != nil {
		t.Fatalf("GetUser 失败: %v", err)
	}
	if u.Nickname != "健身狂人B" {
		t.Errorf("昵称应为 健身狂人B，实际 %q", u.Nickname)
	}
	if u.Timezone != "Asia/Shanghai" {
		t.Errorf("时区应为 Asia/Shanghai，实际 %q", u.Timezone)
	}
	if len(u.Preferences.Crowds) != 1 || u.Preferences.Crowds[0] != "fitness" {
		t.Errorf("u_2 的人群标签应为 [fitness]，实际 %v", u.Preferences.Crowds)
	}
	// 空数组必须是 []，不能是 nil —— 否则会序列化成 null，违反契约。
	if u.Preferences.AvoidFoods == nil {
		t.Error("avoidFoods 为 nil，应为空数组")
	}
}

func TestGetUserReturnsNotFoundForUnknownID(t *testing.T) {
	db := testDB(t)
	s := NewMySQLUserStore(db)

	if _, err := s.GetUser(context.Background(), "u_不存在"); err == nil {
		t.Fatal("未知用户应返回错误")
	}
}

func TestUserIDByTokenResolvesSeedTokens(t *testing.T) {
	db := testDB(t)
	s := NewMySQLUserStore(db)

	for token, want := range map[string]string{
		"dev-token-user-1": "u_1",
		"dev-token-user-2": "u_2",
		"dev-token-user-3": "u_3",
	} {
		got, err := s.UserIDByToken(context.Background(), token)
		if err != nil {
			t.Fatalf("解析 %s 失败: %v", token, err)
		}
		if got != want {
			t.Errorf("%s 应解析为 %s，实际 %s", token, want, got)
		}
	}
}

func TestListRecipesReturnsTwelveWithTags(t *testing.T) {
	db := testDB(t)
	s := NewMySQLRecipeStore(db)

	recipes, err := s.ListRecipes(context.Background())
	if err != nil {
		t.Fatalf("ListRecipes 失败: %v", err)
	}
	if len(recipes) != 12 {
		t.Fatalf("种子菜谱应为 12 条，实际 %d", len(recipes))
	}

	byID := make(map[string]models.Recipe, len(recipes))
	for _, r := range recipes {
		byID[r.ID] = r
	}

	soup, ok := byID["r_01"]
	if !ok {
		t.Fatal("缺少 r_01")
	}
	if soup.Name != "番茄炒蛋" {
		t.Errorf("r_01 名称应为 番茄炒蛋，实际 %q", soup.Name)
	}
	if soup.Calories != 180 {
		t.Errorf("r_01 热量应为 180，实际 %d", soup.Calories)
	}
	if !soup.IsVegetarian {
		t.Error("r_01 应为素食")
	}
	if len(soup.Crowds) != 2 {
		t.Errorf("r_01 应命中 2 个人群标签，实际 %v", soup.Crowds)
	}

	// avoidTags 必须非 nil，且 r_05 应带 pork 与 spicy。
	if soup.AvoidTags == nil {
		t.Error("avoidTags 为 nil，应为空数组")
	}
	mapo, ok := byID["r_05"]
	if !ok {
		t.Fatal("缺少 r_05")
	}
	if len(mapo.AvoidTags) != 2 {
		t.Errorf("r_05 应有 2 个忌口标签，实际 %v", mapo.AvoidTags)
	}
}

func TestOptionsReturnsAllThreeDictionaries(t *testing.T) {
	db := testDB(t)
	s := NewMySQLOptionsStore(db)

	opts, err := s.Options(context.Background())
	if err != nil {
		t.Fatalf("Options 失败: %v", err)
	}
	if len(opts.DietModes) != 2 {
		t.Errorf("dietModes 应为 2 项，实际 %d", len(opts.DietModes))
	}
	if len(opts.Crowds) != 5 {
		t.Errorf("crowds 应为 5 项，实际 %d", len(opts.Crowds))
	}
	if len(opts.AvoidFoods) != 5 {
		t.Errorf("avoidFoods 应为 5 项，实际 %d", len(opts.AvoidFoods))
	}
	if opts.Crowds[0].Code != "pregnant" || opts.Crowds[0].Label != "孕妇" {
		t.Errorf("crowds 首项应按 sort_order 为 pregnant/孕妇，实际 %+v", opts.Crowds[0])
	}
}

// UpdatePreferences 是全量替换：写进去的必须原样读出来，未提交的必须被清掉。
func TestUpdatePreferencesIsFullReplace(t *testing.T) {
	db := testDB(t)
	s := NewMySQLUserStore(db)
	ctx := context.Background()

	const userID = "u_3"
	original, err := s.GetPreferences(ctx, userID)
	if err != nil {
		t.Fatalf("读取原始偏好失败: %v", err)
	}
	t.Cleanup(func() {
		if err := s.UpdatePreferences(ctx, userID, original); err != nil {
			t.Errorf("恢复原始偏好失败: %v", err)
		}
	})

	next := models.NewPreferences("vegetarian", []string{"fitness", "athlete"},
		[]string{"pork", "seafood"})
	if err := s.UpdatePreferences(ctx, userID, next); err != nil {
		t.Fatalf("写入偏好失败: %v", err)
	}

	got, err := s.GetPreferences(ctx, userID)
	if err != nil {
		t.Fatalf("回读偏好失败: %v", err)
	}
	if got.DietMode != "vegetarian" {
		t.Errorf("dietMode 应为 vegetarian，实际 %q", got.DietMode)
	}
	if len(got.Crowds) != 2 {
		t.Errorf("crowds 应为 2 项（原 student 应已被替换掉），实际 %v", got.Crowds)
	}
	if len(got.AvoidFoods) != 2 {
		t.Errorf("avoidFoods 应为 2 项，实际 %v", got.AvoidFoods)
	}

	// 再写一次空数组，验证旧值被清干净。
	if err := s.UpdatePreferences(ctx, userID,
		models.NewPreferences("normal", nil, nil)); err != nil {
		t.Fatalf("写入空偏好失败: %v", err)
	}
	cleared, err := s.GetPreferences(ctx, userID)
	if err != nil {
		t.Fatalf("回读空偏好失败: %v", err)
	}
	if len(cleared.Crowds) != 0 || len(cleared.AvoidFoods) != 0 {
		t.Errorf("应被清空，实际 crowds=%v avoidFoods=%v", cleared.Crowds, cleared.AvoidFoods)
	}
}
