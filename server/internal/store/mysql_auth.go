package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/go-sql-driver/mysql"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type MySQLAuthStore struct{ db *sql.DB }

func NewMySQLAuthStore(db *sql.DB) *MySQLAuthStore { return &MySQLAuthStore{db: db} }

// mysqlDuplicateEntry 是 MySQL 的 ER_DUP_ENTRY 错误号。
// 用错误号而不是匹配错误文案：文案随版本和语言变化，错误号不会。
const mysqlDuplicateEntry = 1062

func isDuplicateEntry(err error) bool {
	var me *mysql.MySQLError
	return errors.As(err, &me) && me.Number == mysqlDuplicateEntry
}

// LatestSmsCode 按 id 倒序而不是 created_at 倒序取最新一条。
// created_at 是秒粒度的 DATETIME，同一秒内连发两条会并列，
// 此时 created_at 无法定序；id 是自增的，永远有全序。
func (s *MySQLAuthStore) LatestSmsCode(ctx context.Context, phone string) (models.SmsCode, error) {
	var (
		sc         models.SmsCode
		consumedAt sql.NullTime
	)
	err := s.db.QueryRowContext(ctx,
		`SELECT id, phone, code, expires_at, consumed_at, attempts, created_at
		   FROM sms_codes WHERE phone = ? ORDER BY id DESC LIMIT 1`, phone).
		Scan(&sc.ID, &sc.Phone, &sc.Code, &sc.ExpiresAt, &consumedAt, &sc.Attempts, &sc.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return models.SmsCode{}, ErrNotFound
	}
	if err != nil {
		return models.SmsCode{}, fmt.Errorf("查询验证码失败: %w", err)
	}
	if consumedAt.Valid {
		t := consumedAt.Time
		sc.ConsumedAt = &t
	}
	return sc, nil
}

// CreateSmsCode 显式写入 created_at 而不是靠列默认值，
// 让它与 expires_at 出自同一个时钟读数 —— 两处各取一次 now 会引入毫秒级漂移，
// 虽然无害，但「签发时间 + TTL == 过期时间」这个等式在排查时会很有用。
func (s *MySQLAuthStore) CreateSmsCode(
	ctx context.Context, phone, code string, expiresAt time.Time,
) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO sms_codes (phone, code, expires_at, created_at) VALUES (?, ?, ?, ?)`,
		phone, code, expiresAt.UTC(), time.Now().UTC())
	if err != nil {
		return fmt.Errorf("写入验证码失败: %w", err)
	}
	return nil
}

// ConsumeSmsCode 是「仅当尚未消费」的条件更新。
// 影响行数为 0 说明已被别的请求抢先消费，返回 ErrNotFound 让调用方按
// 「验证码不可用」处理 —— 一次性由此成立，不依赖调用方先读后写的时序。
func (s *MySQLAuthStore) ConsumeSmsCode(ctx context.Context, id int64, at time.Time) error {
	res, err := s.db.ExecContext(ctx,
		`UPDATE sms_codes SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL`,
		at.UTC(), id)
	if err != nil {
		return fmt.Errorf("标记验证码已用失败: %w", err)
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("标记验证码已用失败: %w", err)
	}
	if affected == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *MySQLAuthStore) IncreaseSmsAttempts(ctx context.Context, id int64) error {
	if _, err := s.db.ExecContext(ctx,
		`UPDATE sms_codes SET attempts = attempts + 1 WHERE id = ?`, id); err != nil {
		return fmt.Errorf("累加验证码失败次数失败: %w", err)
	}
	return nil
}

func (s *MySQLAuthStore) CountSmsCodesSince(
	ctx context.Context, phone string, since time.Time,
) (int, error) {
	var n int
	err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM sms_codes WHERE phone = ? AND created_at >= ?`,
		phone, since.UTC()).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("统计验证码发送次数失败: %w", err)
	}
	return n, nil
}

func (s *MySQLAuthStore) UserIDByPhone(ctx context.Context, phone string) (string, error) {
	var userID string
	err := s.db.QueryRowContext(ctx, `SELECT id FROM users WHERE phone = ?`, phone).Scan(&userID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("按手机号查询用户失败: %w", err)
	}
	return userID, nil
}

// CreateUserWithPhone 在一个事务里建用户 + 写默认偏好。
//
// 分两步而不是给 user_preferences 一个触发器：注册出来的用户必须带着一行偏好，
// 否则 GetPreferences 会走进「查不到 diet_mode 就返回默认值」的分支 ——
// 结果碰巧一样，但那意味着这个用户永远没有偏好行，
// PUT /me/preferences 的 upsert 之前都得先靠这个巧合兜着。
func (s *MySQLAuthStore) CreateUserWithPhone(
	ctx context.Context, u models.User, phone string,
) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	// 提交成功后 Rollback 返回 ErrTxDone，此处可安全忽略。
	defer tx.Rollback() //nolint:errcheck

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO users (id, nickname, avatar_text, timezone, phone) VALUES (?, ?, ?, ?, ?)`,
		u.ID, u.Nickname, u.AvatarText, u.Timezone, phone); err != nil {
		// 并发注册同一号码时另一次请求已经建好了，交给调用方去复用它。
		if isDuplicateEntry(err) {
			return ErrDuplicate
		}
		return fmt.Errorf("创建用户失败: %w", err)
	}

	if _, err := tx.ExecContext(ctx,
		`INSERT INTO user_preferences (user_id, diet_mode) VALUES (?, ?)`,
		u.ID, u.Preferences.DietMode); err != nil {
		return fmt.Errorf("写入默认偏好失败: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("提交注册失败: %w", err)
	}
	return nil
}
