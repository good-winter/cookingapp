package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type MySQLOptionsStore struct{ db *sql.DB }

func NewMySQLOptionsStore(db *sql.DB) *MySQLOptionsStore { return &MySQLOptionsStore{db: db} }

func (s *MySQLOptionsStore) Options(ctx context.Context) (models.PreferenceOptions, error) {
	dietModes, err := s.listOptions(ctx, "diet_modes")
	if err != nil {
		return models.PreferenceOptions{}, err
	}
	crowds, err := s.listOptions(ctx, "crowds")
	if err != nil {
		return models.PreferenceOptions{}, err
	}
	avoids, err := s.listOptions(ctx, "avoid_foods")
	if err != nil {
		return models.PreferenceOptions{}, err
	}
	return models.PreferenceOptions{
		DietModes:  dietModes,
		Crowds:     crowds,
		AvoidFoods: avoids,
	}, nil
}

// table 只来自本文件内的字面量，不是用户输入，无注入风险。
func (s *MySQLOptionsStore) listOptions(ctx context.Context, table string) ([]models.Option, error) {
	rows, err := s.db.QueryContext(ctx,
		fmt.Sprintf(`SELECT code, label FROM %s ORDER BY sort_order, code`, table))
	if err != nil {
		return nil, fmt.Errorf("查询 %s 失败: %w", table, err)
	}
	defer rows.Close()

	out := []models.Option{}
	for rows.Next() {
		var o models.Option
		if err := rows.Scan(&o.Code, &o.Label); err != nil {
			return nil, fmt.Errorf("扫描 %s 失败: %w", table, err)
		}
		out = append(out, o)
	}
	return out, rows.Err()
}
