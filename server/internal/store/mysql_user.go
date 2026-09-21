package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type MySQLUserStore struct{ db *sql.DB }

func NewMySQLUserStore(db *sql.DB) *MySQLUserStore { return &MySQLUserStore{db: db} }

// UserIDByToken 实现 TokenStore。
// 将来换成 JWT 时只需替换本方法——这正是把它放在中间件之后的用意。
func (s *MySQLUserStore) UserIDByToken(ctx context.Context, token string) (string, error) {
	var userID string
	err := s.db.QueryRowContext(ctx,
		`SELECT user_id FROM api_tokens WHERE token = ?`, token).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("查询 token 失败: %w", err)
	}
	return userID, nil
}

func (s *MySQLUserStore) GetUser(ctx context.Context, userID string) (models.User, error) {
	var u models.User
	err := s.db.QueryRowContext(ctx,
		`SELECT id, nickname, avatar_text, timezone FROM users WHERE id = ?`, userID).
		Scan(&u.ID, &u.Nickname, &u.AvatarText, &u.Timezone)
	if errors.Is(err, sql.ErrNoRows) {
		return models.User{}, ErrNotFound
	}
	if err != nil {
		return models.User{}, fmt.Errorf("查询用户失败: %w", err)
	}

	prefs, err := s.GetPreferences(ctx, userID)
	if err != nil {
		return models.User{}, err
	}
	u.Preferences = prefs
	return u, nil
}

func (s *MySQLUserStore) GetPreferences(ctx context.Context, userID string) (models.Preferences, error) {
	var dietMode string
	err := s.db.QueryRowContext(ctx,
		`SELECT diet_mode FROM user_preferences WHERE user_id = ?`, userID).Scan(&dietMode)
	if errors.Is(err, sql.ErrNoRows) {
		// 用户存在但从未设置过偏好时，返回契约定义的默认值而不是报错。
		return models.NewPreferences("normal", nil, nil), nil
	}
	if err != nil {
		return models.Preferences{}, fmt.Errorf("查询偏好失败: %w", err)
	}

	crowds, err := s.listValues(ctx,
		`SELECT crowd FROM user_preference_crowds WHERE user_id = ?`, userID)
	if err != nil {
		return models.Preferences{}, err
	}
	avoids, err := s.listValues(ctx,
		`SELECT avoid_food FROM user_preference_avoids WHERE user_id = ?`, userID)
	if err != nil {
		return models.Preferences{}, err
	}
	return models.NewPreferences(dietMode, crowds, avoids), nil
}

func (s *MySQLUserStore) listValues(ctx context.Context, query, userID string) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("查询偏好明细失败: %w", err)
	}
	defer rows.Close()

	out := []string{}
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, fmt.Errorf("扫描偏好明细失败: %w", err)
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// UpdatePreferences 是全量替换语义，与 PUT 契约一致。
func (s *MySQLUserStore) UpdatePreferences(
	ctx context.Context, userID string, prefs models.Preferences,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	// 提交成功后 Rollback 返回 ErrTxDone，此处可安全忽略。
	defer tx.Rollback() //nolint:errcheck

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO user_preferences (user_id, diet_mode) VALUES (?, ?)
		 ON DUPLICATE KEY UPDATE diet_mode = VALUES(diet_mode)`,
		userID, prefs.DietMode); err != nil {
		return fmt.Errorf("写入偏好失败: %w", err)
	}

	if _, err := tx.ExecContext(ctx,
		`DELETE FROM user_preference_crowds WHERE user_id = ?`, userID); err != nil {
		return fmt.Errorf("清除旧人群标签失败: %w", err)
	}
	for _, c := range prefs.Crowds {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO user_preference_crowds (user_id, crowd) VALUES (?, ?)`,
			userID, c); err != nil {
			return fmt.Errorf("写入人群标签失败: %w", err)
		}
	}

	if _, err := tx.ExecContext(ctx,
		`DELETE FROM user_preference_avoids WHERE user_id = ?`, userID); err != nil {
		return fmt.Errorf("清除旧忌口失败: %w", err)
	}
	for _, a := range prefs.AvoidFoods {
		if _, err := tx.ExecContext(ctx,
			`INSERT INTO user_preference_avoids (user_id, avoid_food) VALUES (?, ?)`,
			userID, a); err != nil {
			return fmt.Errorf("写入忌口失败: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("提交偏好失败: %w", err)
	}
	return nil
}
