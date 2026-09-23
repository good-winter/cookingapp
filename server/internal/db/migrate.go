package db

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"sort"
	"strings"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// Migrate 按文件名顺序执行内嵌的迁移文件，已执行过的跳过。
// DSN 必须启用 multiStatements=true，否则整份 .sql 无法一次执行。
//
// **每个迁移文件都必须自身幂等**（建表带 IF NOT EXISTS、插数据带 INSERT IGNORE）。
// 原因是这里是「先执行、后记录」且没有事务保护：MySQL 的 DDL 会隐式提交，
// 用事务包住给不了真正的原子性，反而会让人误以为中途失败可以回滚。于是进程若在
// 执行与记录之间挂掉，下次启动会重跑整份文件——幂等是唯一能保证服务仍然起得来的
// 前提。详见 migrations/0002_seed.sql 顶部的说明。
func Migrate(ctx context.Context, conn *sql.DB) error {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return fmt.Errorf("读取迁移目录失败: %w", err)
	}

	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names) // 文件名前缀数字保证执行顺序

	if _, err := conn.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (
		filename   VARCHAR(128) NOT NULL PRIMARY KEY,
		applied_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`); err != nil {
		return fmt.Errorf("创建 schema_migrations 失败: %w", err)
	}

	for _, name := range names {
		var exists int
		if err := conn.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM schema_migrations WHERE filename = ?`, name).Scan(&exists); err != nil {
			return fmt.Errorf("查询迁移状态失败 %s: %w", name, err)
		}
		if exists > 0 {
			continue
		}

		content, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("读取迁移文件失败 %s: %w", name, err)
		}

		if _, err := conn.ExecContext(ctx, string(content)); err != nil {
			return fmt.Errorf("执行迁移失败 %s: %w", name, err)
		}
		if _, err := conn.ExecContext(ctx,
			`INSERT INTO schema_migrations (filename) VALUES (?)`, name); err != nil {
			return fmt.Errorf("记录迁移失败 %s: %w", name, err)
		}
	}
	return nil
}
