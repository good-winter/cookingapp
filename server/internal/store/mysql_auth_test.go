package store

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/good-winter/cookingapp/server/internal/models"
)

// 集成测试用独立号码，不碰种子数据里的任何东西。
// users 上的外键是 ON DELETE CASCADE，删用户会连带清掉它的偏好与 token；
// sms_codes 没有外键，得单独删 —— 各用例的 t.Cleanup 分别处理。
const authTestPhone = "13900009999"

func TestSmsCodeLifecycle(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	s := NewMySQLAuthStore(db)

	t.Cleanup(func() {
		_, _ = db.ExecContext(ctx, `DELETE FROM sms_codes WHERE phone = ?`, authTestPhone)
	})

	// 起始状态：没有记录。
	if _, err := s.LatestSmsCode(ctx, authTestPhone); !errors.Is(err, ErrNotFound) {
		t.Fatalf("无记录时应返回 ErrNotFound，实际 %v", err)
	}

	expires := time.Now().UTC().Add(5 * time.Minute).Truncate(time.Second)
	if err := s.CreateSmsCode(ctx, authTestPhone, "123456", expires); err != nil {
		t.Fatalf("CreateSmsCode 失败: %v", err)
	}

	got, err := s.LatestSmsCode(ctx, authTestPhone)
	if err != nil {
		t.Fatalf("LatestSmsCode 失败: %v", err)
	}
	if got.Code != "123456" {
		t.Errorf("验证码应为 123456，实际 %q", got.Code)
	}
	// consumed_at 是可空列，NULL 必须映射成 nil 指针而不是零值时间 ——
	// 否则「未消费」会被读成「已消费于公元 1 年」。
	if got.ConsumedAt != nil {
		t.Errorf("未消费的记录 ConsumedAt 应为 nil，实际 %v", got.ConsumedAt)
	}
	if !got.ExpiresAt.Equal(expires) {
		t.Errorf("过期时间应往返一致：期望 %v，实际 %v", expires, got.ExpiresAt)
	}
	if got.Attempts != 0 {
		t.Errorf("初始失败次数应为 0，实际 %d", got.Attempts)
	}

	// 失败计数自增。由 SQL 做 +1 而不是读-改-写，并发下才不会互相覆盖。
	if err := s.IncreaseSmsAttempts(ctx, got.ID); err != nil {
		t.Fatalf("IncreaseSmsAttempts 失败: %v", err)
	}
	if err := s.IncreaseSmsAttempts(ctx, got.ID); err != nil {
		t.Fatalf("IncreaseSmsAttempts 失败: %v", err)
	}
	after, _ := s.LatestSmsCode(ctx, authTestPhone)
	if after.Attempts != 2 {
		t.Errorf("失败次数应累加到 2，实际 %d", after.Attempts)
	}

	// 条件消费：第一次成功，第二次必须失败（一次性）。
	if err := s.ConsumeSmsCode(ctx, got.ID, time.Now().UTC()); err != nil {
		t.Fatalf("首次消费应成功: %v", err)
	}
	if err := s.ConsumeSmsCode(ctx, got.ID, time.Now().UTC()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("重复消费应返回 ErrNotFound，实际 %v", err)
	}

	consumed, _ := s.LatestSmsCode(ctx, authTestPhone)
	if consumed.ConsumedAt == nil {
		t.Error("消费后 ConsumedAt 不应为 nil")
	}
}

// LatestSmsCode 必须按 id 而非 created_at 取最新：created_at 是秒粒度，
// 同一秒内连发两条会并列，此时只有 id 能定序。
func TestLatestSmsCodeBreaksSameSecondTies(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	s := NewMySQLAuthStore(db)

	t.Cleanup(func() {
		_, _ = db.ExecContext(ctx, `DELETE FROM sms_codes WHERE phone = ?`, authTestPhone)
	})

	expires := time.Now().UTC().Add(5 * time.Minute)
	if err := s.CreateSmsCode(ctx, authTestPhone, "111111", expires); err != nil {
		t.Fatalf("CreateSmsCode 失败: %v", err)
	}
	if err := s.CreateSmsCode(ctx, authTestPhone, "222222", expires); err != nil {
		t.Fatalf("CreateSmsCode 失败: %v", err)
	}

	got, err := s.LatestSmsCode(ctx, authTestPhone)
	if err != nil {
		t.Fatalf("LatestSmsCode 失败: %v", err)
	}
	if got.Code != "222222" {
		t.Errorf("应取到后写入的那条（222222），实际 %q", got.Code)
	}

	// 计数用于当日上限。
	n, err := s.CountSmsCodesSince(ctx, authTestPhone, time.Now().UTC().Add(-time.Hour))
	if err != nil {
		t.Fatalf("CountSmsCodesSince 失败: %v", err)
	}
	if n != 2 {
		t.Errorf("一小时内应计到 2 条，实际 %d", n)
	}
	// 时间窗之外的不该计入。
	n, err = s.CountSmsCodesSince(ctx, authTestPhone, time.Now().UTC().Add(time.Hour))
	if err != nil {
		t.Fatalf("CountSmsCodesSince 失败: %v", err)
	}
	if n != 0 {
		t.Errorf("未来时间窗应计到 0 条，实际 %d", n)
	}
}

func TestCreateUserWithPhoneRegistersWithDefaultPreferences(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	s := NewMySQLAuthStore(db)

	t.Cleanup(func() {
		_, _ = db.ExecContext(ctx, `DELETE FROM users WHERE phone = ?`, authTestPhone)
	})
	_, _ = db.ExecContext(ctx, `DELETE FROM users WHERE phone = ?`, authTestPhone)

	// 起始状态：该号码未注册。
	if _, err := s.UserIDByPhone(ctx, authTestPhone); !errors.Is(err, ErrNotFound) {
		t.Fatalf("未注册号码应返回 ErrNotFound，实际 %v", err)
	}

	id := "u_test_auth"
	user := models.NewUserForPhone(id, authTestPhone)
	if err := s.CreateUserWithPhone(ctx, user, authTestPhone); err != nil {
		t.Fatalf("CreateUserWithPhone 失败: %v", err)
	}

	gotID, err := s.UserIDByPhone(ctx, authTestPhone)
	if err != nil {
		t.Fatalf("UserIDByPhone 失败: %v", err)
	}
	if gotID != id {
		t.Errorf("应按号码取回 %s，实际 %s", id, gotID)
	}

	// 注册必须连带写一行偏好：否则 GetPreferences 会走「查不到就返回默认值」
	// 的分支，看起来一样，但那个用户可以一直没有偏好行。
	users := NewMySQLUserStore(db)
	prefs, err := users.GetPreferences(ctx, id)
	if err != nil {
		t.Fatalf("GetPreferences 失败: %v", err)
	}
	if prefs.DietMode != "normal" {
		t.Errorf("默认 dietMode 应为 normal，实际 %q", prefs.DietMode)
	}
	if len(prefs.Crowds) != 0 || len(prefs.AvoidFoods) != 0 {
		t.Errorf("默认人群与忌口应为空，实际 %v / %v", prefs.Crowds, prefs.AvoidFoods)
	}

	// 同一号码再注册一次 → ErrDuplicate，调用方据此改为复用。
	// 这条是并发注册（连点两次登录）的正确性基础。
	err = s.CreateUserWithPhone(ctx, models.NewUserForPhone("u_test_auth2", authTestPhone), authTestPhone)
	if !errors.Is(err, ErrDuplicate) {
		t.Fatalf("重复号码应返回 ErrDuplicate，实际 %v", err)
	}
}

func TestCreateTokenIsAcceptedByUserIDByToken(t *testing.T) {
	db := testDB(t)
	ctx := context.Background()
	s := NewMySQLUserStore(db)

	const token = "test-issued-token-0001"
	t.Cleanup(func() {
		_, _ = db.ExecContext(ctx, `DELETE FROM api_tokens WHERE token = ?`, token)
	})

	if err := s.CreateToken(ctx, token, "u_2"); err != nil {
		t.Fatalf("CreateToken 失败: %v", err)
	}
	// 签发的 token 必须能被鉴权中间件那条查询解析出来 ——
	// 这是「登录拿到的 token 能否访问其它接口」的根。
	userID, err := s.UserIDByToken(ctx, token)
	if err != nil {
		t.Fatalf("UserIDByToken 失败: %v", err)
	}
	if userID != "u_2" {
		t.Errorf("期望解析出 u_2，实际 %s", userID)
	}
}
