package store

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type MySQLRecipeStore struct{ db *sql.DB }

func NewMySQLRecipeStore(db *sql.DB) *MySQLRecipeStore { return &MySQLRecipeStore{db: db} }

// ListRecipes 返回全部菜谱。菜谱库规模很小（种子数据 12 条），
// 因此过滤与排序交给纯函数 recommend.Rank 处理，便于单元测试且无需数据库。
func (s *MySQLRecipeStore) ListRecipes(ctx context.Context) ([]models.Recipe, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, name, emoji, image_url, cook_time_minutes, is_vegetarian,
		       calories, carbs_percent, protein_percent, fat_percent
		FROM recipes`)
	if err != nil {
		return nil, fmt.Errorf("查询菜谱失败: %w", err)
	}
	defer rows.Close()

	recipes := []models.Recipe{}
	byID := make(map[string]int)
	for rows.Next() {
		var r models.Recipe
		var imageURL sql.NullString
		if err := rows.Scan(&r.ID, &r.Name, &r.Emoji, &imageURL, &r.CookTimeMinutes,
			&r.IsVegetarian, &r.Calories, &r.Nutrition.CarbsPercent,
			&r.Nutrition.ProteinPercent, &r.Nutrition.FatPercent); err != nil {
			return nil, fmt.Errorf("扫描菜谱失败: %w", err)
		}
		if imageURL.Valid {
			r.ImageURL = &imageURL.String
		}
		r.Crowds = []string{}
		r.AvoidTags = []string{}
		byID[r.ID] = len(recipes)
		recipes = append(recipes, r)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("遍历菜谱失败: %w", err)
	}
	if len(recipes) == 0 {
		return recipes, nil
	}

	// 标签单独查询再回填，避免 JOIN 造成笛卡尔积产生重复行。
	if err := s.attachTags(ctx, recipes, byID, "recipe_crowds", "crowd",
		func(r *models.Recipe, v string) { r.Crowds = append(r.Crowds, v) }); err != nil {
		return nil, err
	}
	if err := s.attachTags(ctx, recipes, byID, "recipe_avoid_tags", "avoid_tag",
		func(r *models.Recipe, v string) { r.AvoidTags = append(r.AvoidTags, v) }); err != nil {
		return nil, err
	}
	return recipes, nil
}

// table 与 column 只来自本文件内的字面量，recipe id 走占位符，无注入风险。
func (s *MySQLRecipeStore) attachTags(
	ctx context.Context,
	recipes []models.Recipe,
	byID map[string]int,
	table, column string,
	assign func(*models.Recipe, string),
) error {
	placeholders := make([]string, len(recipes))
	args := make([]any, len(recipes))
	for i, r := range recipes {
		placeholders[i] = "?"
		args[i] = r.ID
	}

	query := fmt.Sprintf(`SELECT recipe_id, %s FROM %s WHERE recipe_id IN (%s)`,
		column, table, strings.Join(placeholders, ","))
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("查询 %s 失败: %w", table, err)
	}
	defer rows.Close()

	for rows.Next() {
		var recipeID, value string
		if err := rows.Scan(&recipeID, &value); err != nil {
			return fmt.Errorf("扫描 %s 失败: %w", table, err)
		}
		if idx, ok := byID[recipeID]; ok {
			assign(&recipes[idx], value)
		}
	}
	return rows.Err()
}
