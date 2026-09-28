-- 手机号 + 短信验证码登录。
--
-- 本文件必须整份可重复执行：migrate.go 是「先执行、后记账」且不在事务里，
-- 所以任何一步失败都不会记账，下次启动会把整个文件重跑一遍。
-- CREATE TABLE IF NOT EXISTS 天然满足；users.phone 那条 ALTER 不能直接写 ——
-- MySQL 8.0 不支持 ADD COLUMN IF NOT EXISTS（那是 MariaDB 的扩展），
-- 重跑时会报 Error 1060 Duplicate column name 并 log.Fatalf 让服务起不来。
--
-- 时间列一律按 UTC 写入：DSN 带 loc=UTC，写入方必须用 time.Now().UTC()，
-- 拿本地时间比会差 8 小时，症状是验证码「一发出就过期」。

-- 短信验证码。一次性消费（consumed_at），带失败计数（attempts）。
CREATE TABLE IF NOT EXISTS sms_codes (
  id          BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  phone       VARCHAR(20) NOT NULL,
  code        VARCHAR(8)  NOT NULL,
  expires_at  DATETIME    NOT NULL,
  consumed_at DATETIME    NULL,
  attempts    INT         NOT NULL DEFAULT 0,
  created_at  DATETIME    NOT NULL,
  INDEX idx_sms_phone_created (phone, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- users.phone：登录账号。可空 —— 三个种子用户与将来的第三方登录用户都没有手机号。
-- 唯一键让「同一号码并发注册」退化为一条失败而非产生两个账号。
SET @has_phone := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'phone');

SET @ddl := IF(@has_phone = 0,
  'ALTER TABLE users ADD COLUMN phone VARCHAR(20) NULL, ADD UNIQUE KEY uk_users_phone (phone)',
  'DO 0');

PREPARE add_phone FROM @ddl;
EXECUTE add_phone;
DEALLOCATE PREPARE add_phone;
