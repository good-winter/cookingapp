# cookingapp 后端实现计划（Phase 0 + Phase 1）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭起 cookingapp 的 Go 后端骨架，交付 Phase 0（数据库 schema + 种子数据）与 Phase 1（用户与偏好、菜谱推荐共 4 个接口），让前端可以开始联调。

**Architecture:** 标准 REST 服务，Gin 负责 HTTP 层，`database/sql` 直连 MySQL（不引 ORM）。分层为 handler → store（接口）→ MySQL 实现。**推荐算法实现为纯函数**，不碰数据库，因此可以完全不依赖 MySQL 做单元测试——这是本计划里唯一有真实业务逻辑的部分，必须能快速测试。

**Tech Stack:** Go 1.25（本机已装）、Gin、MySQL 8.0（本机 `MySQL80` 服务运行中）、`go-sql-driver/mysql`、`database/sql`

**Spec:** `docs/API_CONTRACT.md`

---

## Global Constraints

以下约定对每个任务都生效，逐字抄自契约：

- **Base URL 前缀：** `/api/v1`
- **字段命名：** `camelCase`，不使用 snake_case
- **响应包：** 不包裹 `{code, message, data}` 外壳，直接用 HTTP 状态码 + 资源本体
- **错误格式：** `{"error": {"code": "...", "message": "...", "details": {}}}`。`details` 无内容时返回 `{}`，不是 `null`
- **鉴权：** 除健康检查外，所有接口要求 `Authorization: Bearer <token>`
- **时间：** ISO 8601 带时区，只返回绝对时间
- **热量单位：** `kcal`，JSON number
- **错误码枚举：** `UNAUTHORIZED` / `FORBIDDEN` / `USER_NOT_FOUND` / `RECIPE_NOT_FOUND` / `POST_NOT_FOUND` / `IMAGE_NOT_RECOGNIZED` / `IMAGE_TOO_LARGE` / `UNSUPPORTED_IMAGE_FORMAT` / `INVALID_PARAMETER` / `RATE_LIMITED` / `INTERNAL_ERROR`
- **空数组不能序列化成 `null`：** `crowds`、`avoidFoods`、`avoidTags`、`items`、`hashtags` 在为空时必须输出 `[]`。Go 里 `nil` slice 会序列化成 `null`，**每个构造这些字段的位置都要初始化为空 slice**
- **枚举英文码（唯一权威定义）：**
  - `dietMode`: `normal` / `vegetarian`
  - `crowds`: `pregnant` / `student` / `fitness` / `elderly` / `athlete`
  - `avoidFoods`: `pork` / `beef` / `seafood` / `cilantro` / `spicy`
- **数据库时区：** 一律存 UTC，DSN 带 `parseTime=true&loc=UTC`。「自然日」按用户 `timezone` 字段计算（Phase 2 才用到）
- **MySQL 连接串必须带 `charset=utf8mb4`**，否则中文菜名会乱码或写入失败

---

## Phase 1 任务前的决策（评审意见处置）

前端评审者提出的 10 条 + 删除端点，处置如下。**Task 1 会把这些写进契约。**

| # | 评审问题 | 处置 |
|---|---|---|
| 1 | `Post.author.tag` 单值语义未定义 | **把 `author.tag` 改为 `author.tags` 数组**，不做「取第一个」这种武断截断。前端渲染 `tags.first` 或空 |
| 2 | `MealRecord` 缺 `createdAt`，游标无稳定全序 | 采纳。`MealRecord` 加 `createdAt`，排序键固定为 `(createdAt DESC, id DESC)` |
| 3 | 图片大小上限未定义 | 采纳。**上限 5 MB**，接受格式 `jpg` / `jpeg` / `png` / `webp` |
| 4 | 开发期怎么切换 token | 采纳。前端用 `--dart-define=API_TOKEN=...`，配 3 个 launch 配置，token 不落盘。**后端额外支持 `X-Debug-Token` 请求头覆盖**，仅 `APP_ENV=development` 时生效，供前端在设置页做运行时切换 |
| 5 | `nutritionPercent` 无法区分数据来源 | 采纳。`/stats/summary` 返回 `estimatedRatio`（0–1），表示营养数据中来自模型估算的比例 |
| 6 | 枚举 label 映射表不完整 | 采纳，但**明确边界**：`dietModes` / `crowds` / `avoidFoods` 由**服务端下发**（数据驱动，可能增删）；`freshness` / `nutritionSource` / `MealRecord.source` 是**闭集**，文案由前端本地 l10n 维护，不走接口 |
| 7 | `MealRecord` 缺 `recipeId` | 采纳。加可空的 `recipeId` |
| 8 | 偏好变更后必须丢弃游标 | 采纳，写进契约正文 |
| 9 | 保存偏好成功但重拉推荐失败的中间态 | 采纳。契约规定：前端必须显式报错并提供重试，**不得静默展示不一致数据** |
| 10 | `/preferences/options` 缓存策略自相矛盾 | 采纳。明确为：**每次启动拉取一次，内存缓存，不落盘** |
| — | 缺删除类端点 | 采纳。新增 `DELETE /api/v1/stats/records`（204）与 `DELETE /api/v1/posts/{id}`（204，非本人 403） |
| — | 契约中描述前端现状的部分已过时 | 采纳。修正：`shared_preferences` 已用于持久化、已存在 `fromJson`/`toJson`、改造清单需基于新文件树、社区 `TabController` 需从 3 改 2 |
| — | 「不要删除 test/widget_test.dart」 | 采纳。撤回原建议，该文件已重写且 48 个用例通过，是回归网 |

**本期不做：** 评论相关端点（评论数据模型尚未定义），推迟到评论模型落地后。

---

## File Structure

```
server/
├── go.mod
├── .env.example                        # 环境变量样例（.env 进 .gitignore）
├── cmd/
│   └── api/
│       └── main.go                     # 装配：config → db → migrate → router → ListenAndServe
└── internal/
    ├── config/
    │   └── config.go                   # 环境变量读取与校验
    ├── db/
    │   ├── db.go                       # 连接、Ping
    │   ├── migrate.go                  # 执行内嵌 SQL 迁移
    │   └── migrations/
    │       ├── 0001_schema.sql         # 建表
    │       └── 0002_seed.sql           # 种子数据
    ├── httputil/
    │   └── httputil.go                 # 错误码常量、错误信封、Abort 助手
    ├── middleware/
    │   └── auth.go                     # Bearer token → userID 中间件
    ├── models/
    │   └── models.go                   # User / Preferences / Recipe / Option 等
    ├── store/
    │   ├── store.go                    # 接口定义 + ErrNotFound
    │   ├── mysql_user.go               # UserStore 的 MySQL 实现
    │   ├── mysql_options.go            # OptionsStore 的 MySQL 实现
    │   └── mysql_recipe.go             # RecipeStore 的 MySQL 实现
    ├── recommend/
    │   ├── recommend.go                # Rank + 游标分页（纯函数，无 DB 依赖）
    │   └── recommend_test.go
    └── api/
        ├── router.go                   # 路由注册
        ├── handler.go                  # Handler 结构体与构造
        ├── me.go                       # GET /me
        ├── preferences.go              # PUT /me/preferences
        ├── options.go                  # GET /preferences/options
        └── recipes.go                  # GET /recipes/recommend
```

设计要点：

- **`recommend` 是独立包且不 import `store`**，只依赖 `models`。这样推荐逻辑的测试不需要数据库。
- **`store` 只定义接口，MySQL 实现分开文件**。handler 依赖接口，测试可注入假实现。
- **`httputil` 不含业务逻辑**，只有错误码常量和响应助手。

---

## Task 1: 契约 v2 定稿与文档归并

**Files:**
- Modify: `docs/API_CONTRACT.md`
- Delete: `docs/superpowers/specs/2026-09-21-cookingapp-api-design.md`

**Interfaces:**
- Consumes: 无
- Produces: 唯一的规范契约文件 `docs/API_CONTRACT.md`，后续所有任务以它为准

先把契约改对，再写代码。这一步同时解决两份文档并存的漂移风险。

- [ ] **Step 1: 合并两份契约文档**

`docs/API_CONTRACT.md`（评审者所在路径）作为**唯一规范文件**；删除 `docs/superpowers/specs/2026-09-21-cookingapp-api-design.md`。理由：评审者已经在用前者的路径，且它额外含评审意见；两份并存必然漂移。

```bash
git rm docs/superpowers/specs/2026-09-21-cookingapp-api-design.md
```

- [ ] **Step 2: 把「处置表」的结论写进契约正文**

在 `docs/API_CONTRACT.md` 的对应章节逐条落地：

- `Post` 模型的 `author.tag` 改为 `author.tags`，类型为数组（枚举同 `crowds`）
- `MealRecord` 增加 `createdAt`（ISO 8601）与可空 `recipeId`
- 新增「上传限制」小节：图片上限 5 MB，格式 `jpg` / `jpeg` / `png` / `webp`
- 新增「分页排序键」约定：所有游标分页的稳定排序键固定为 `(createdAt DESC, id DESC)`；`/recipes/recommend` 例外，用 `(匹配人群数 DESC, id ASC)`
- `/stats/summary` 响应增加 `estimatedRatio`（0–1，number）
- `/preferences/options` 的缓存策略改为「每次启动拉取一次，内存缓存，不落盘」
- 明确枚举边界：`dietModes`/`crowds`/`avoidFoods` 服务端下发；`freshness`/`nutritionSource`/`MealRecord.source` 是闭集，文案由前端 l10n 维护
- `/recipes/recommend` 补一句：偏好变更后已签发的 `cursor` 失效，前端必须丢弃

- [ ] **Step 3: 新增删除类端点**

在契约「接口清单」中新增：

```
DELETE /api/v1/stats/records     → 204，清除当前用户的全部饮食记录
DELETE /api/v1/posts/{id}        → 204，删除自己的帖子；非本人 → 403 FORBIDDEN
```

并在错误码表中确认 `FORBIDDEN` 已列出（已在）。

- [ ] **Step 4: 修正契约中过时的前端现状描述**

- 「`shared_preferences` 全项目零引用」→ 已用于本地持久化，删除该断言
- 「全项目没有任何 `fromJson` / `toJson`」→ 已存在，删除该断言
- 「前端改造清单」的逐文件表格：按新文件树重写——`features/cooking/` 下已新增 `data/mock_recipes.dart`、`models/recipe.dart`、`services/recipe_recommender.dart` 三层；`core/utils/greeting.dart`、`core/storage/preference_storage.dart`、`core/bootstrap.dart` 已存在
- 补充遗漏的 UI 改动：社区页 `TabController(length: 3)` 需改为 `2`（决策 #5 已砍掉同城）
- 「两项清理」中删除「`test/widget_test.dart` 应删除」这一条——该文件已重写，48 个用例通过，是回归网

- [ ] **Step 5: 在评审意见一节标注处置状态**

在 `docs/API_CONTRACT.md` 末尾的「前端评审意见」各条后追加一行 `> 处置：已采纳 / 已采纳（方案见正文 X 节）`，让评审者能直接看到哪条被采纳、落到了哪里。**保留评审原文**，这是协作记录。

- [ ] **Step 6: 提交**

```bash
git add docs/API_CONTRACT.md
git commit -m "docs: 契约 v2，处置前端评审意见并归并为单一文档"
```

---

## Task 2: Go 服务骨架与健康检查

**Files:**
- Create: `server/go.mod`, `server/cmd/api/main.go`, `server/internal/config/config.go`, `server/internal/db/db.go`, `server/internal/httputil/httputil.go`, `server/.env.example`
- Modify: `.gitignore`（加 `server/.env`）
- Test: `server/internal/config/config_test.go`

**Interfaces:**
- Consumes: 无
- Produces:
  - `config.Load() (config.Config, error)`，`Config` 含字段 `Addr`、`DSN`、`Env`、`AutoMigrate`
  - `db.Open(ctx context.Context, dsn string) (*sql.DB, error)`
  - `httputil.Abort(c *gin.Context, status int, code, message string, details map[string]any)`
  - 错误码常量 `httputil.CodeUnauthorized` 等 11 个

- [ ] **Step 1: 写失败的测试**

`server/internal/config/config_test.go`：

```go
package config

import "testing"

func TestLoadRequiresDSN(t *testing.T) {
	t.Setenv("APP_DSN", "")
	if _, err := Load(); err == nil {
		t.Fatal("APP_DSN 缺失时应当返回错误，实际返回 nil")
	}
}

func TestLoadDefaults(t *testing.T) {
	t.Setenv("APP_DSN", "user:pass@tcp(127.0.0.1:3306)/cookingapp")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("不应报错: %v", err)
	}
	if cfg.Addr != ":8080" {
		t.Errorf("Addr 默认值应为 :8080，实际 %q", cfg.Addr)
	}
	if cfg.Env != "development" {
		t.Errorf("Env 默认值应为 development，实际 %q", cfg.Env)
	}
	if !cfg.AutoMigrate {
		t.Error("AutoMigrate 默认值应为 true")
	}
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/config/ -v
```

预期：编译失败，`undefined: Load`。

- [ ] **Step 3: 初始化 Go module**

```bash
cd server
go mod init github.com/good-winter/cookingapp/server
go get github.com/gin-gonic/gin@latest
go get github.com/go-sql-driver/mysql@latest
go get github.com/joho/godotenv@latest
```

- [ ] **Step 4: 实现 config**

`server/internal/config/config.go`：

```go
package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	Addr        string
	DSN         string
	Env         string
	AutoMigrate bool
}

func Load() (Config, error) {
	cfg := Config{
		Addr: getenv("APP_ADDR", ":8080"),
		Env:  getenv("APP_ENV", "development"),
		DSN:  os.Getenv("APP_DSN"),
	}

	if cfg.DSN == "" {
		return Config{}, fmt.Errorf("环境变量 APP_DSN 未设置")
	}

	auto, err := strconv.ParseBool(getenv("APP_AUTO_MIGRATE", "true"))
	if err != nil {
		return Config{}, fmt.Errorf("APP_AUTO_MIGRATE 不是合法布尔值: %w", err)
	}
	cfg.AutoMigrate = auto

	return cfg, nil
}

// IsDevelopment 用于决定是否启用 X-Debug-Token 等仅开发期可用的行为。
func (c Config) IsDevelopment() bool { return c.Env == "development" }

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
```

- [ ] **Step 5: 运行测试确认通过**

```bash
cd server && go test ./internal/config/ -v
```

预期：两条用例 PASS。

- [ ] **Step 6: 实现 httputil**

`server/internal/httputil/httputil.go`：

```go
package httputil

import "github.com/gin-gonic/gin"

// 契约中定义的 error.code 全集。
const (
	CodeUnauthorized           = "UNAUTHORIZED"
	CodeForbidden              = "FORBIDDEN"
	CodeUserNotFound           = "USER_NOT_FOUND"
	CodeRecipeNotFound         = "RECIPE_NOT_FOUND"
	CodePostNotFound           = "POST_NOT_FOUND"
	CodeImageNotRecognized     = "IMAGE_NOT_RECOGNIZED"
	CodeImageTooLarge          = "IMAGE_TOO_LARGE"
	CodeUnsupportedImageFormat = "UNSUPPORTED_IMAGE_FORMAT"
	CodeInvalidParameter       = "INVALID_PARAMETER"
	CodeRateLimited            = "RATE_LIMITED"
	CodeInternalError          = "INTERNAL_ERROR"
)

type ErrorBody struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details"`
}

type errorEnvelope struct {
	Error ErrorBody `json:"error"`
}

// Abort 写出契约约定的错误响应并终止后续 handler。
func Abort(c *gin.Context, status int, code, message string, details map[string]any) {
	if details == nil {
		details = map[string]any{}
	}
	c.AbortWithStatusJSON(status, errorEnvelope{
		Error: ErrorBody{Code: code, Message: message, Details: details},
	})
}
```

- [ ] **Step 7: 实现 db.Open**

`server/internal/db/db.go`：

```go
package db

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func Open(ctx context.Context, dsn string) (*sql.DB, error) {
	conn, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("打开数据库连接失败: %w", err)
	}

	conn.SetMaxOpenConns(25)
	conn.SetMaxIdleConns(25)
	conn.SetConnMaxLifetime(5 * time.Minute)

	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := conn.PingContext(pingCtx); err != nil {
		conn.Close()
		return nil, fmt.Errorf("连接数据库失败: %w", err)
	}
	return conn, nil
}
```

- [ ] **Step 8: 实现 main 与健康检查**

`server/cmd/api/main.go`：

```go
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/db"
)

func main() {
	_ = godotenv.Load() // .env 不存在时不报错

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("配置加载失败: %v", err)
	}

	ctx := context.Background()
	conn, err := db.Open(ctx, cfg.DSN)
	if err != nil {
		log.Fatalf("数据库连接失败: %v", err)
	}
	defer conn.Close()

	if cfg.AutoMigrate {
		if err := db.Migrate(ctx, conn); err != nil {
			log.Fatalf("数据库迁移失败: %v", err)
		}
	}

	if !cfg.IsDevelopment() {
		gin.SetMode(gin.ReleaseMode)
	}
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	srv := &http.Server{Addr: cfg.Addr, Handler: r}

	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("服务启动失败: %v", err)
		}
	}()
	log.Printf("服务已启动，监听 %s（env=%s）", cfg.Addr, cfg.Env)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("关闭服务时出错: %v", err)
	}
}
```

`db.Migrate` 在 Task 3 实现。**本步骤先建一个空实现让它编译通过**，Task 3 再填充：

`server/internal/db/migrate.go`：

```go
package db

import (
	"context"
	"database/sql"
)

func Migrate(ctx context.Context, conn *sql.DB) error {
	return nil // Task 3 填充
}
```

- [ ] **Step 9: 写 .env.example 与 .gitignore**

`server/.env.example`：

```dotenv
# 复制为 .env 并填入真实值。.env 不进版本库。
APP_ADDR=:8080
APP_ENV=development
APP_AUTO_MIGRATE=true

# 注意 charset=utf8mb4 必须保留，否则中文菜名无法写入。
# parseTime=true 让 DATETIME 直接扫描为 time.Time。
# loc=UTC 表示数据库中的时间一律按 UTC 处理。
APP_DSN=root:你的密码@tcp(127.0.0.1:3306)/cookingapp?parseTime=true&loc=UTC&charset=utf8mb4&multiStatements=true
```

在仓库根 `.gitignore` 末尾追加：

```
# 后端本地配置
server/.env
```

- [ ] **Step 10: 编译并冒烟**

```bash
cd server && go build ./... && go vet ./...
```

预期：无输出、退出码 0。

- [ ] **Step 11: 提交**

```bash
git add server/ .gitignore
git commit -m "feat(server): Go 服务骨架、配置加载与健康检查"
```

---

## Task 3: MySQL schema 与迁移

**前置：** 需要先创建数据库。用 MySQL Workbench 或命令行执行：

```sql
CREATE DATABASE IF NOT EXISTS cookingapp
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

**Files:**
- Create: `server/internal/db/migrations/0001_schema.sql`
- Modify: `server/internal/db/migrate.go`
- Test: `server/internal/db/migrate_test.go`

**Interfaces:**
- Consumes: `db.Open`（Task 2）
- Produces: `db.Migrate(ctx context.Context, conn *sql.DB) error` 的真实实现；表结构 `users` / `api_tokens` / `user_preferences` / `user_preference_crowds` / `user_preference_avoids` / `diet_modes` / `crowds` / `avoid_foods` / `recipes` / `recipe_crowds` / `recipe_avoid_tags` / `posts` / `post_hashtags` / `follows` / `meal_records`

- [ ] **Step 1: 写 schema**

`server/internal/db/migrations/0001_schema.sql`：

```sql
-- 用户。timezone 为 IANA 标识，统计接口按它切分自然日。
CREATE TABLE IF NOT EXISTS users (
  id          VARCHAR(32)  NOT NULL PRIMARY KEY,
  nickname    VARCHAR(64)  NOT NULL,
  avatar_text VARCHAR(8)   NOT NULL,
  timezone    VARCHAR(64)  NOT NULL DEFAULT 'Asia/Shanghai',
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 开发期测试 token。将来换成 JWT 时替换本表与中间件实现即可，接口形状不变。
CREATE TABLE IF NOT EXISTS api_tokens (
  token      VARCHAR(128) NOT NULL PRIMARY KEY,
  user_id    VARCHAR(32)  NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 偏好选项字典：下发到前端，新增选项属数据变更，无需发版。
CREATE TABLE IF NOT EXISTS diet_modes (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS crowds (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS avoid_foods (
  code       VARCHAR(32) NOT NULL PRIMARY KEY,
  label      VARCHAR(32) NOT NULL,
  sort_order INT         NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id    VARCHAR(32) NOT NULL PRIMARY KEY,
  diet_mode  VARCHAR(32) NOT NULL DEFAULT 'normal',
  updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_prefs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preference_crowds (
  user_id VARCHAR(32) NOT NULL,
  crowd   VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, crowd),
  CONSTRAINT fk_upc_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_preference_avoids (
  user_id    VARCHAR(32) NOT NULL,
  avoid_food VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, avoid_food),
  CONSTRAINT fk_upa_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 菜谱库。营养数据为统计与自动入账的数据源，不可为空。
CREATE TABLE IF NOT EXISTS recipes (
  id                VARCHAR(32)  NOT NULL PRIMARY KEY,
  name              VARCHAR(64)  NOT NULL,
  emoji             VARCHAR(16)  NOT NULL,
  image_url         VARCHAR(255) NULL,
  cook_time_minutes INT          NOT NULL,
  is_vegetarian     TINYINT(1)   NOT NULL DEFAULT 0,
  calories          INT          NOT NULL,
  carbs_percent     INT          NOT NULL,
  protein_percent   INT          NOT NULL,
  fat_percent       INT          NOT NULL,
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recipe_crowds (
  recipe_id VARCHAR(32) NOT NULL,
  crowd     VARCHAR(32) NOT NULL,
  PRIMARY KEY (recipe_id, crowd),
  CONSTRAINT fk_rc_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS recipe_avoid_tags (
  recipe_id VARCHAR(32) NOT NULL,
  avoid_tag VARCHAR(32) NOT NULL,
  PRIMARY KEY (recipe_id, avoid_tag),
  CONSTRAINT fk_rat_recipe FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS posts (
  id            VARCHAR(32)  NOT NULL PRIMARY KEY,
  author_id     VARCHAR(32)  NOT NULL,
  content       TEXT         NOT NULL,
  image_emoji   VARCHAR(16)  NOT NULL DEFAULT '',
  image_url     VARCHAR(255) NULL,
  like_count    INT          NOT NULL DEFAULT 0,
  comment_count INT          NOT NULL DEFAULT 0,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_posts_author FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_posts_created (created_at DESC, id DESC),
  INDEX idx_posts_author (author_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id  VARCHAR(32) NOT NULL,
  hashtag  VARCHAR(64) NOT NULL,
  PRIMARY KEY (post_id, hashtag),
  CONSTRAINT fk_ph_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS follows (
  follower_id VARCHAR(32) NOT NULL,
  followee_id VARCHAR(32) NOT NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, followee_id),
  CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_follows_followee FOREIGN KEY (followee_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 饮食记录。created_at 是全序排序键（游标分页依赖它）；
-- eaten_on 是用户本地时区的自然日，供统计聚合使用。
-- 营养百分比在入账时快照下来，避免日后改菜谱导致历史数据漂移。
CREATE TABLE IF NOT EXISTS meal_records (
  id                VARCHAR(32) NOT NULL PRIMARY KEY,
  user_id           VARCHAR(32) NOT NULL,
  recipe_id         VARCHAR(32) NULL,
  recipe_name       VARCHAR(64) NOT NULL,
  emoji             VARCHAR(16) NOT NULL DEFAULT '',
  calories          INT         NOT NULL,
  carbs_percent     INT         NOT NULL,
  protein_percent   INT         NOT NULL,
  fat_percent       INT         NOT NULL,
  nutrition_source  VARCHAR(16) NOT NULL,
  eaten_on          DATE        NOT NULL,
  created_at        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_meals_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_meals_user_created (user_id, created_at DESC, id DESC),
  INDEX idx_meals_user_date (user_id, eaten_on)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 记录已执行的迁移，保证重复启动幂等。
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   VARCHAR(128) NOT NULL PRIMARY KEY,
  applied_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: 实现迁移执行器**

`server/internal/db/migrate.go`（整体替换 Task 2 的空实现）：

```go
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
		err := conn.QueryRowContext(ctx,
			`SELECT COUNT(*) FROM schema_migrations WHERE filename = ?`, name).Scan(&exists)
		if err != nil {
			return fmt.Errorf("查询迁移状态失败 %s: %w", name, err)
		}
		if exists > 0 {
			continue
		}

		content, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("读取迁移文件失败 %s: %w", name, err)
		}

		// DSN 已启用 multiStatements=true，可整文件执行。
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
```

- [ ] **Step 3: 编译验证**

```bash
cd server && go build ./... && go vet ./...
```

预期：退出码 0。

- [ ] **Step 4: 对着真实 MySQL 跑迁移**

先建好 `server/.env`（从 `.env.example` 复制并填密码），然后：

```bash
cd server && APP_DSN="$(grep '^APP_DSN=' .env | cut -d= -f2-)" go run ./cmd/api
```

预期：日志出现「服务已启动」，无迁移报错。用 Workbench 刷新应看到 15 张表。

再次运行同一条命令，预期仍无报错且不重复建表——验证幂等。

- [ ] **Step 5: 提交**

```bash
git add server/internal/db/
git commit -m "feat(server): MySQL schema 与幂等迁移执行器"
```

---

## Task 4: 种子数据

**Files:**
- Create: `server/internal/db/migrations/0002_seed.sql`

**Interfaces:**
- Consumes: Task 3 的表结构
- Produces: 3 个测试用户 + 3 个 token + 选项字典 + 12 条带营养数据的菜谱 + 3 条帖子

- [ ] **Step 1: 写种子数据**

`server/internal/db/migrations/0002_seed.sql`：

```sql
-- 选项字典。新增选项只需在此表加行，前端无需发版。
INSERT INTO diet_modes (code, label, sort_order) VALUES
  ('normal',     '正常人',   1),
  ('vegetarian', '素食主义', 2);

INSERT INTO crowds (code, label, sort_order) VALUES
  ('pregnant', '孕妇',     1),
  ('student',  '学生',     2),
  ('fitness',  '健身人群', 3),
  ('elderly',  '老人',     4),
  ('athlete',  '运动员',   5);

INSERT INTO avoid_foods (code, label, sort_order) VALUES
  ('pork',     '猪肉', 1),
  ('beef',     '牛肉', 2),
  ('seafood',  '海鲜', 3),
  ('cilantro', '香菜', 4),
  ('spicy',    '辛辣', 5);

-- 测试用户。头像用文字代替图片。timezone 决定统计的自然日切分。
INSERT INTO users (id, nickname, avatar_text, timezone) VALUES
  ('u_1', '美食家',   '美', 'Asia/Shanghai'),
  ('u_2', '健身狂人B', '健', 'Asia/Shanghai'),
  ('u_3', '厨房小白C', '厨', 'Asia/Shanghai');

INSERT INTO user_preferences (user_id, diet_mode) VALUES
  ('u_1', 'normal'),
  ('u_2', 'normal'),
  ('u_3', 'normal');

INSERT INTO user_preference_crowds (user_id, crowd) VALUES
  ('u_2', 'fitness'),
  ('u_3', 'student');

-- 开发期 token。多个 token 是为了让前端能验证关注流（关注是用户之间的动作）。
INSERT INTO api_tokens (token, user_id) VALUES
  ('dev-token-user-1', 'u_1'),
  ('dev-token-user-2', 'u_2'),
  ('dev-token-user-3', 'u_3');

-- 菜谱库。营养数据是统计与自动入账的数据源。
-- 注意：以下热量与营养比例为演示用估值，不是营养学准确数据；
-- 上线前需要换成可靠来源。
INSERT INTO recipes
  (id, name, emoji, cook_time_minutes, is_vegetarian, calories,
   carbs_percent, protein_percent, fat_percent) VALUES
  ('r_01', '番茄炒蛋',   '🍲', 10, 1, 180, 50, 25, 25),
  ('r_02', '红烧肉',     '🥩', 45, 0, 450, 20, 20, 60),
  ('r_03', '香煎鸡胸肉', '🍗', 15, 0, 250, 15, 55, 30),
  ('r_04', '清蒸鲈鱼',   '🐟', 20, 0, 200, 10, 60, 30),
  ('r_05', '麻婆豆腐',   '🌶️', 15, 0, 280, 25, 25, 50),
  ('r_06', '白灼西兰花', '🥦',  8, 1,  80, 60, 30, 10),
  ('r_07', '清炒时蔬',   '🥬',  8, 1,  90, 65, 20, 15),
  ('r_08', '小米南瓜粥', '🥣', 30, 1, 150, 75, 15, 10),
  ('r_09', '黑椒牛柳',   '🥘', 20, 0, 320, 20, 45, 35),
  ('r_10', '蒜蓉粉丝虾', '🦐', 25, 0, 220, 40, 35, 25),
  ('r_11', '凉拌黄瓜',   '🥒',  5, 1,  60, 70, 15, 15),
  ('r_12', '西红柿牛腩', '🍅', 90, 0, 380, 25, 35, 40);

INSERT INTO recipe_crowds (recipe_id, crowd) VALUES
  ('r_01', 'pregnant'), ('r_01', 'student'),
  ('r_03', 'fitness'),  ('r_03', 'athlete'),
  ('r_04', 'elderly'),  ('r_04', 'pregnant'),
  ('r_05', 'student'),
  ('r_06', 'fitness'),  ('r_06', 'elderly'),
  ('r_08', 'elderly'),  ('r_08', 'pregnant'),
  ('r_09', 'athlete'),
  ('r_11', 'fitness');

INSERT INTO recipe_avoid_tags (recipe_id, avoid_tag) VALUES
  ('r_02', 'pork'),
  ('r_05', 'pork'), ('r_05', 'spicy'),
  ('r_04', 'seafood'),
  ('r_10', 'seafood'),
  ('r_09', 'beef'),
  ('r_12', 'beef');

-- 帖子。created_at 用固定时间而非 NOW()，保证种子数据可复现。
INSERT INTO posts (id, author_id, content, image_emoji, like_count, comment_count, created_at) VALUES
  ('p_01', 'u_2',
   '今天用App的AI识别挑的西红柿，做的番茄炒蛋太香了！AI提示我孕妇要少吃某种香料，真的帮了大忙。',
   '🍲', 128, 45, '2026-09-21 12:00:00'),
  ('p_02', 'u_2',
   '求问：健身完吃这个热量超了吗？App统计说这顿大概350大卡，我觉得还行？',
   '🥗', 12, 89, '2026-09-21 11:00:00'),
  ('p_03', 'u_3',
   '跟着沉浸式做饭模式一步一步来，居然没翻车！语音播报太适合我这种手忙脚乱的人了。',
   '🍳', 56, 23, '2026-09-21 10:00:00');

INSERT INTO post_hashtags (post_id, hashtag) VALUES
  ('p_01', '孕妇餐'), ('p_01', '快手菜'), ('p_01', '番茄炒蛋'),
  ('p_02', '减脂餐'), ('p_02', '低卡'),   ('p_02', '健身'),
  ('p_03', '学生党'), ('p_03', '新手做饭'), ('p_03', '沉浸式做饭');

-- u_1 关注 u_2，让「关注」feed 一开始就有内容可验证。
INSERT INTO follows (follower_id, followee_id) VALUES ('u_1', 'u_2');
```

- [ ] **Step 2: 跑迁移灌入种子**

```bash
cd server && go run ./cmd/api
```

预期：日志无报错；Workbench 中 `recipes` 有 12 行、`users` 3 行、`posts` 3 行。

- [ ] **Step 3: 验证中文未乱码**

在 Workbench 执行 `SELECT name FROM recipes WHERE id = 'r_01';`，预期输出 `番茄炒蛋`。若显示乱码，说明 DSN 少了 `charset=utf8mb4`。

- [ ] **Step 4: 提交**

```bash
git add server/internal/db/migrations/0002_seed.sql
git commit -m "feat(server): 种子数据（用户/token/选项字典/菜谱库/帖子）"
```

---

## Task 5: 领域模型与 store 接口

**Files:**
- Create: `server/internal/models/models.go`, `server/internal/store/store.go`, `server/internal/store/mysql_user.go`, `server/internal/store/mysql_options.go`, `server/internal/store/mysql_recipe.go`, `server/internal/store/mysql_user_test.go`

**Interfaces:**
- Consumes: Task 3 的表结构、Task 4 的种子数据
- Produces:
  - `models.User{ID, Nickname, AvatarText, Timezone, Preferences}`
  - `models.Preferences{DietMode string; Crowds, AvoidFoods []string}`
  - `models.Recipe{ID, Name, Emoji string; ImageURL *string; CookTimeMinutes int; IsVegetarian bool; Crowds, AvoidTags []string; Calories int; Nutrition models.Nutrition}`
  - `models.Nutrition{CarbsPercent, ProteinPercent, FatPercent int}`
  - `models.Option{Code, Label string}`、`models.PreferenceOptions{DietModes, Crowds, AvoidFoods []Option}`
  - `store.ErrNotFound`
  - `store.UserStore` 接口：`GetUser(ctx, userID) (models.User, error)`、`GetPreferences(ctx, userID) (models.Preferences, error)`、`UpdatePreferences(ctx, userID, prefs) error`
  - `store.TokenStore` 接口：`UserIDByToken(ctx, token) (string, error)`
  - `store.OptionsStore` 接口：`Options(ctx) (models.PreferenceOptions, error)`
  - `store.RecipeStore` 接口：`ListRecipes(ctx) ([]models.Recipe, error)`
  - `store.NewMySQLUserStore(db *sql.DB) *MySQLUserStore`、`store.NewMySQLOptionsStore(...)`、`store.NewMySQLRecipeStore(...)`

- [ ] **Step 1: 写 models**

`server/internal/models/models.go`：

```go
package models

type User struct {
	ID          string      `json:"id"`
	Nickname    string      `json:"nickname"`
	AvatarText  string      `json:"avatarText"`
	Timezone    string      `json:"timezone"`
	Preferences Preferences `json:"preferences"`
}

type Preferences struct {
	DietMode   string   `json:"dietMode"`
	Crowds     []string `json:"crowds"`
	AvoidFoods []string `json:"avoidFoods"`
}

// NewPreferences 保证数组字段非 nil——nil slice 会被序列化成 null，
// 而契约要求空数组输出 []。
func NewPreferences(dietMode string, crowds, avoidFoods []string) Preferences {
	return Preferences{
		DietMode:   dietMode,
		Crowds:     orEmpty(crowds),
		AvoidFoods: orEmpty(avoidFoods),
	}
}

type Nutrition struct {
	CarbsPercent   int `json:"carbsPercent"`
	ProteinPercent int `json:"proteinPercent"`
	FatPercent     int `json:"fatPercent"`
}

type Recipe struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Emoji           string    `json:"emoji"`
	ImageURL        *string   `json:"imageUrl"`
	CookTimeMinutes int       `json:"cookTimeMinutes"`
	IsVegetarian    bool      `json:"isVegetarian"`
	Crowds          []string  `json:"crowds"`
	AvoidTags       []string  `json:"avoidTags"`
	Calories        int       `json:"calories"`
	Nutrition       Nutrition `json:"nutrition"`
}

type Option struct {
	Code  string `json:"code"`
	Label string `json:"label"`
}

type PreferenceOptions struct {
	DietModes  []Option `json:"dietModes"`
	Crowds     []Option `json:"crowds"`
	AvoidFoods []Option `json:"avoidFoods"`
}

func orEmpty(s []string) []string {
	if s == nil {
		return []string{}
	}
	return s
}
```

- [ ] **Step 2: 写 store 接口**

`server/internal/store/store.go`：

```go
package store

import (
	"context"
	"errors"

	"github.com/good-winter/cookingapp/server/internal/models"
)

var ErrNotFound = errors.New("资源不存在")

type UserStore interface {
	GetUser(ctx context.Context, userID string) (models.User, error)
	GetPreferences(ctx context.Context, userID string) (models.Preferences, error)
	UpdatePreferences(ctx context.Context, userID string, prefs models.Preferences) error
}

type TokenStore interface {
	UserIDByToken(ctx context.Context, token string) (string, error)
}

type OptionsStore interface {
	Options(ctx context.Context) (models.PreferenceOptions, error)
}

type RecipeStore interface {
	ListRecipes(ctx context.Context) ([]models.Recipe, error)
}
```

- [ ] **Step 3: 写 MySQL 实现**

`server/internal/store/mysql_recipe.go`：

```go
package store

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type MySQLRecipeStore struct{ db *sql.DB }

func NewMySQLRecipeStore(db *sql.DB) *MySQLRecipeStore { return &MySQLRecipeStore{db: db} }

func (s *MySQLRecipeStore) ListRecipes(ctx context.Context) ([]models.Recipe, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, name, emoji, image_url, cook_time_minutes, is_vegetarian,
		       calories, carbs_percent, protein_percent, fat_percent
		FROM recipes`)
	if err != nil {
		return nil, fmt.Errorf("查询菜谱失败: %w", err)
	}
	defer rows.Close()

	recipes := make([]models.Recipe, 0)
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

	// 标签另起查询再回填，避免 JOIN 造成的笛卡尔积导致重复行。
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

func (s *MySQLRecipeStore) attachTags(
	ctx context.Context, recipes []models.Recipe, byID map[string]int,
	table, column string, assign func(*models.Recipe, string),
) error {
	if len(recipes) == 0 {
		return nil
	}
	ids := make([]any, 0, len(recipes))
	placeholders := ""
	for i, r := range recipes {
		if i > 0 {
			placeholders += ","
		}
		placeholders += "?"
		ids = append(ids, r.ID)
	}

	query := fmt.Sprintf(`SELECT recipe_id, %s FROM %s WHERE recipe_id IN (%s)`, column, table, placeholders)
	rows, err := s.db.QueryContext(ctx, query, ids...)
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
```

`server/internal/store/mysql_user.go`：

```go
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

// UserIDByToken 实现 TokenStore。将来换成 JWT 时只需替换本方法的实现。
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
		// 用户存在但尚未设置过偏好时，返回契约定义的默认值而非报错。
		return models.NewPreferences("normal", nil, nil), nil
	}
	if err != nil {
		return models.Preferences{}, fmt.Errorf("查询偏好失败: %w", err)
	}

	crowds, err := s.listValues(ctx, `SELECT crowd FROM user_preference_crowds WHERE user_id = ?`, userID)
	if err != nil {
		return models.Preferences{}, err
	}
	avoids, err := s.listValues(ctx, `SELECT avoid_food FROM user_preference_avoids WHERE user_id = ?`, userID)
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

// UpdatePreferences 全量替换语义，与 PUT 契约一致。
func (s *MySQLUserStore) UpdatePreferences(ctx context.Context, userID string, prefs models.Preferences) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer tx.Rollback() //nolint:errcheck // 提交成功后 Rollback 返回 ErrTxDone，可忽略

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
```

`server/internal/store/mysql_options.go`：

```go
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
	return models.PreferenceOptions{DietModes: dietModes, Crowds: crowds, AvoidFoods: avoids}, nil
}

func (s *MySQLOptionsStore) listOptions(ctx context.Context, table string) ([]models.Option, error) {
	// table 不是用户输入，只来自本文件内的字面量，无注入风险。
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
```

- [ ] **Step 4: 编译验证**

```bash
cd server && go build ./... && go vet ./...
```

预期：退出码 0。

- [ ] **Step 5: 提交**

```bash
git add server/internal/models/ server/internal/store/
git commit -m "feat(server): 领域模型、store 接口与 MySQL 实现"
```

---

## Task 6: 推荐算法与游标分页（纯函数）

这是全项目唯一有真实业务逻辑的部分，也是**完全不依赖数据库**就能测的部分。务必先写测试。

**Files:**
- Create: `server/internal/recommend/recommend.go`, `server/internal/recommend/recommend_test.go`

**Interfaces:**
- Consumes: `models.Recipe`、`models.Preferences`（Task 5）
- Produces:
  - `recommend.Rank(recipes []models.Recipe, prefs models.Preferences) []recommend.Scored`
  - `recommend.Scored{Recipe models.Recipe; Score int}`
  - `recommend.Page(ranked []Scored, limit int, cursor string) (items []models.Recipe, nextCursor *string, err error)`
  - `recommend.ErrInvalidCursor`

**排序契约（必须与 v2 契约一致）：** 先按匹配人群数**降序**，同分再按 `id` **升序**。这个全序是游标分页正确性的前提。

- [ ] **Step 1: 写失败的测试**

`server/internal/recommend/recommend_test.go`：

```go
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
	got := ids(recipeList(Rank(recipes, models.NewPreferences("normal", []string{"fitness", "pregnant"}, nil))))
	want := []string{"r_1", "r_2", "r_3"}
	if !equal(got, want) {
		t.Fatalf("命中越多越靠前、同分按 id 升序；期望 %v，实际 %v", want, got)
	}
}

func TestRankToleratesNilSlices(t *testing.T) {
	recipes := []models.Recipe{recipe("r_1", true, nil, nil)}
	got := Rank(recipes, models.NewPreferences("normal", nil, nil))
	if len(got) != 1 {
		t.Fatalf("nil 标签不应导致 panic 或过滤掉菜谱，实际 %d 条", len(got))
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
	for i := 0; i < 10; i++ { // 上限 10 次防御死循环
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
		t.Fatalf("翻页应不重不漏地走完全部；期望 %v，实际 %v", ids(recipeList(ranked)), seen)
	}
}

func TestPageRejectsMalformedCursor(t *testing.T) {
	if _, _, err := Page(nil, 2, "这不是合法游标"); err == nil {
		t.Fatal("非法游标应返回错误")
	}
}

func recipeList(scored []Scored) []models.Recipe {
	out := make([]models.Recipe, len(scored))
	for i, s := range scored {
		out[i] = s.Recipe
	}
	return out
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/recommend/ -v
```

预期：编译失败，`undefined: Rank`。

- [ ] **Step 3: 实现推荐与分页**

`server/internal/recommend/recommend.go`：

```go
package recommend

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"sort"

	"github.com/good-winter/cookingapp/server/internal/models"
)

var ErrInvalidCursor = errors.New("游标非法或已失效")

const (
	MaxLimit     = 50
	DefaultLimit = 10
)

type Scored struct {
	Recipe models.Recipe
	Score  int
}

// Rank 按当前偏好过滤并排序菜谱。
// 排序契约：匹配人群数降序，同分按 id 升序——这个全序是游标分页正确性的前提。
func Rank(recipes []models.Recipe, prefs models.Preferences) []Scored {
	out := make([]Scored, 0, len(recipes))
	for _, r := range recipes {
		if prefs.DietMode == "vegetarian" && !r.IsVegetarian {
			continue
		}
		if containsAny(r.AvoidTags, prefs.AvoidFoods) {
			continue
		}
		out = append(out, Scored{Recipe: r, Score: countMatches(r.Crowds, prefs.Crowds)})
	}

	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		return out[i].Recipe.ID < out[j].Recipe.ID
	})
	return out
}

func containsAny(haystack, needles []string) bool {
	for _, n := range needles {
		for _, h := range haystack {
			if h == n {
				return true
			}
		}
	}
	return false
}

func countMatches(haystack, needles []string) int {
	n := 0
	for _, h := range haystack {
		for _, needle := range needles {
			if h == needle {
				n++
				break
			}
		}
	}
	return n
}

// cursor 内容对调用方不透明，仅本包能解释。
type cursorPayload struct {
	Score int    `json:"s"`
	ID    string `json:"i"`
}

func encodeCursor(score int, id string) string {
	raw, _ := json.Marshal(cursorPayload{Score: score, ID: id})
	return base64.RawURLEncoding.EncodeToString(raw)
}

func decodeCursor(raw string) (cursorPayload, error) {
	data, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return cursorPayload{}, ErrInvalidCursor
	}
	var p cursorPayload
	if err := json.Unmarshal(data, &p); err != nil || p.ID == "" {
		return cursorPayload{}, ErrInvalidCursor
	}
	return p, nil
}

// comesAfter 判断 item 在排序中是否严格位于 cur 之后。
func comesAfter(item Scored, cur cursorPayload) bool {
	if item.Score != cur.Score {
		return item.Score < cur.Score // 分数降序
	}
	return item.Recipe.ID > cur.ID // 同分按 id 升序
}

// Page 从已排序结果中切出一页。nextCursor 为 nil 表示没有下一页。
func Page(ranked []Scored, limit int, cursor string) ([]models.Recipe, *string, error) {
	if limit <= 0 {
		limit = DefaultLimit
	}
	if limit > MaxLimit {
		limit = MaxLimit
	}

	start := 0
	if cursor != "" {
		cur, err := decodeCursor(cursor)
		if err != nil {
			return nil, nil, err
		}
		for start < len(ranked) && !comesAfter(ranked[start], cur) {
			start++
		}
	}

	end := start + limit
	if end > len(ranked) {
		end = len(ranked)
	}

	items := make([]models.Recipe, 0, end-start)
	for _, s := range ranked[start:end] {
		items = append(items, s.Recipe)
	}

	if end >= len(ranked) {
		return items, nil, nil
	}
	last := ranked[end-1]
	next := encodeCursor(last.Score, last.Recipe.ID)
	return items, &next, nil
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd server && go test ./internal/recommend/ -v
```

预期：6 条用例全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add server/internal/recommend/
git commit -m "feat(server): 推荐排序与游标分页（纯函数）"
```

---

## Task 7: 鉴权中间件

**Files:**
- Create: `server/internal/middleware/auth.go`, `server/internal/middleware/auth_test.go`

**Interfaces:**
- Consumes: `store.TokenStore`、`httputil.Abort`（Task 2/5）
- Produces:
  - `middleware.ContextUserID` 常量（值为 `"userID"`）
  - `middleware.Auth(tokens store.TokenStore, allowDebugHeader bool) gin.HandlerFunc`

`X-Debug-Token` 仅在 `allowDebugHeader` 为 true（即 `APP_ENV=development`）时生效，供前端做运行时切换用户。

- [ ] **Step 1: 写失败的测试**

`server/internal/middleware/auth_test.go`：

```go
package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/store"
)

type fakeTokens struct{ valid map[string]string }

func (f fakeTokens) UserIDByToken(_ context.Context, token string) (string, error) {
	if id, ok := f.valid[token]; ok {
		return id, nil
	}
	return "", store.ErrNotFound
}

func newTestRouter(tokens store.TokenStore, allowDebug bool) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/probe", Auth(tokens, allowDebug), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"userID": c.GetString(ContextUserID)})
	})
	return r
}

func do(t *testing.T, r *gin.Engine, headers map[string]string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/probe", nil)
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	var body struct {
		UserID string `json:"userID"`
		Error  struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &body)
	if body.Error.Code != "" {
		return w.Code, body.Error.Code
	}
	return w.Code, body.UserID
}

func TestAuthAcceptsValidBearerToken(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, got := do(t, r, map[string]string{"Authorization": "Bearer dev-token-user-1"})
	if code != http.StatusOK || got != "u_1" {
		t.Fatalf("期望 200 + u_1，实际 %d + %q", code, got)
	}
}

func TestAuthRejectsMissingHeader(t *testing.T) {
	r := newTestRouter(fakeTokens{}, true)
	code, errCode := do(t, r, nil)
	if code != http.StatusUnauthorized || errCode != "UNAUTHORIZED" {
		t.Fatalf("期望 401 + UNAUTHORIZED，实际 %d + %q", code, errCode)
	}
}

func TestAuthRejectsUnknownToken(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, errCode := do(t, r, map[string]string{"Authorization": "Bearer 乱写的"})
	if code != http.StatusUnauthorized || errCode != "UNAUTHORIZED" {
		t.Fatalf("期望 401 + UNAUTHORIZED，实际 %d + %q", code, errCode)
	}
}

func TestAuthRejectsNonBearerScheme(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}}, true)
	code, _ := do(t, r, map[string]string{"Authorization": "Basic dev-token-user-1"})
	if code != http.StatusUnauthorized {
		t.Fatalf("非 Bearer 方案应拒绝，实际 %d", code)
	}
}

func TestAuthDebugHeaderHonoredInDevelopment(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-2": "u_2"}}, true)
	code, got := do(t, r, map[string]string{"X-Debug-Token": "dev-token-user-2"})
	if code != http.StatusOK || got != "u_2" {
		t.Fatalf("开发期应接受 X-Debug-Token，实际 %d + %q", code, got)
	}
}

func TestAuthDebugHeaderIgnoredOutsideDevelopment(t *testing.T) {
	r := newTestRouter(fakeTokens{valid: map[string]string{"dev-token-user-2": "u_2"}}, false)
	code, _ := do(t, r, map[string]string{"X-Debug-Token": "dev-token-user-2"})
	if code != http.StatusUnauthorized {
		t.Fatalf("非开发期必须忽略 X-Debug-Token，实际 %d", code)
	}
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/middleware/ -v
```

预期：编译失败，`undefined: Auth`。

- [ ] **Step 3: 实现中间件**

`server/internal/middleware/auth.go`：

```go
package middleware

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/store"
)

const ContextUserID = "userID"

// Auth 解析 token 并注入当前用户 ID。
// allowDebugHeader 为 true 时额外接受 X-Debug-Token，用于开发期运行时切换用户。
func Auth(tokens store.TokenStore, allowDebugHeader bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := bearerToken(c.GetHeader("Authorization"))
		if token == "" && allowDebugHeader {
			token = strings.TrimSpace(c.GetHeader("X-Debug-Token"))
		}
		if token == "" {
			httputil.Abort(c, http.StatusUnauthorized, httputil.CodeUnauthorized,
				"缺少访问令牌", nil)
			return
		}

		userID, err := tokens.UserIDByToken(c.Request.Context(), token)
		if err != nil {
			if !errors.Is(err, store.ErrNotFound) {
				httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
					"服务器内部错误", nil)
				return
			}
			httputil.Abort(c, http.StatusUnauthorized, httputil.CodeUnauthorized,
				"访问令牌无效", nil)
			return
		}

		c.Set(ContextUserID, userID)
		c.Next()
	}
}

// bearerToken 从 Authorization 头取出 token，方案名大小写不敏感。
func bearerToken(header string) string {
	const prefix = "Bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return ""
	}
	return strings.TrimSpace(header[len(prefix):])
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd server && go test ./internal/middleware/ -v
```

预期：6 条用例全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add server/internal/middleware/
git commit -m "feat(server): Bearer 鉴权中间件与开发期调试 token"
```

---

## Task 8: 路由装配与 GET /me

**Files:**
- Create: `server/internal/api/router.go`, `server/internal/api/handler.go`, `server/internal/api/me.go`, `server/internal/api/me_test.go`
- Modify: `server/cmd/api/main.go`

**Interfaces:**
- Consumes: Task 2/5/7 的全部产物
- Produces:
  - `api.Handler` 结构体，字段 `Users store.UserStore`、`Tokens store.TokenStore`、`Options store.OptionsStore`、`Recipes store.RecipeStore`
  - `api.NewRouter(cfg config.Config, h *Handler) *gin.Engine`
  - `(h *Handler) GetMe(c *gin.Context)`

- [ ] **Step 1: 写失败的测试**

`server/internal/api/me_test.go`：

```go
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type fakeUsers struct {
	user map[string]models.User
}

func (f fakeUsers) GetUser(_ context.Context, userID string) (models.User, error) {
	u, ok := f.user[userID]
	if !ok {
		return models.User{}, store.ErrNotFound
	}
	return u, nil
}

func (f fakeUsers) GetPreferences(_ context.Context, userID string) (models.Preferences, error) {
	u, ok := f.user[userID]
	if !ok {
		return models.Preferences{}, store.ErrNotFound
	}
	return u.Preferences, nil
}

func (f fakeUsers) UpdatePreferences(_ context.Context, userID string, p models.Preferences) error {
	u, ok := f.user[userID]
	if !ok {
		return store.ErrNotFound
	}
	u.Preferences = p
	f.user[userID] = u
	return nil
}

type fakeTokens struct{ valid map[string]string }

func (f fakeTokens) UserIDByToken(_ context.Context, token string) (string, error) {
	if id, ok := f.valid[token]; ok {
		return id, nil
	}
	return "", store.ErrNotFound
}

func testRouter(t *testing.T) *gin.Engine {
	t.Helper()
	h := &Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {
				ID: "u_1", Nickname: "美食家", AvatarText: "美", Timezone: "Asia/Shanghai",
				Preferences: models.NewPreferences("normal", []string{"pregnant"}, nil),
			},
		}},
		Tokens: fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}},
	}
	return NewRouter(config.Config{Env: "development"}, h)
}

func TestGetMeReturnsUserWithPreferences(t *testing.T) {
	r := testRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer dev-token-user-1")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", w.Code, w.Body.String())
	}
	var got models.User
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("响应不是合法 User: %v", err)
	}
	if got.ID != "u_1" || got.Nickname != "美食家" {
		t.Errorf("用户字段不符: %+v", got)
	}
	if len(got.Preferences.Crowds) != 1 || got.Preferences.Crowds[0] != "pregnant" {
		t.Errorf("偏好不符: %+v", got.Preferences)
	}
}

func TestGetMeEmitsEmptyArraysNotNull(t *testing.T) {
	r := testRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	req.Header.Set("Authorization", "Bearer dev-token-user-1")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// avoidFoods 为空，契约要求输出 []，不能是 null。
	if body := w.Body.String(); !contains(body, `"avoidFoods":[]`) {
		t.Fatalf("空数组必须序列化为 []，实际 body=%s", body)
	}
}

func TestGetMeRequiresAuth(t *testing.T) {
	r := testRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/me", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("未带 token 应返回 401，实际 %d", w.Code)
	}
}

func contains(haystack, needle string) bool {
	return strings.Contains(haystack, needle)
}
```

在该文件的 import 块中补两个包：

```go
	"strings"

	"github.com/gin-gonic/gin"
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/api/ -v
```

预期：编译失败，`undefined: Handler`。

- [ ] **Step 3: 实现 handler 与 router**

`server/internal/api/handler.go`：

```go
package api

import "github.com/good-winter/cookingapp/server/internal/store"

type Handler struct {
	Users   store.UserStore
	Tokens  store.TokenStore
	Options store.OptionsStore
	Recipes store.RecipeStore
}
```

`server/internal/api/router.go`：

```go
package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/config"
	"github.com/good-winter/cookingapp/server/internal/middleware"
)

func NewRouter(cfg config.Config, h *Handler) *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })

	v1 := r.Group("/api/v1")
	v1.Use(middleware.Auth(h.Tokens, cfg.IsDevelopment()))
	{
		v1.GET("/me", h.GetMe)
	}

	return r
}
```

`server/internal/api/me.go`：

```go
package api

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/store"
)

func (h *Handler) GetMe(c *gin.Context) {
	userID := c.GetString(middleware.ContextUserID)

	user, err := h.Users.GetUser(c.Request.Context(), userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, user)
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd server && go test ./internal/api/ -v
```

预期：3 条用例 PASS。

- [ ] **Step 5: 接进 main.go**

在 `server/cmd/api/main.go` 中**删除** Task 2 留下的临时路由（4 行）：

```go
	r := gin.New()
	r.Use(gin.Recovery())
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})
```

在 `srv := &http.Server{...}` 那一行**之前**插入：

```go
	handler := &api.Handler{
		Users:   store.NewMySQLUserStore(conn),
		Tokens:  store.NewMySQLUserStore(conn),
		Options: store.NewMySQLOptionsStore(conn),
		Recipes: store.NewMySQLRecipeStore(conn),
	}
```

把 `srv := &http.Server{Addr: cfg.Addr, Handler: r}` 改为：

```go
	srv := &http.Server{Addr: cfg.Addr, Handler: api.NewRouter(cfg, handler)}
```

`if !cfg.IsDevelopment() { gin.SetMode(gin.ReleaseMode) }` 保持原样不动。删除 `r := gin.New()` 那 4 行后，`gin` 包仍被 `gin.SetMode` 与 `gin.Context` 使用，import 无需删。

并补 import：

```go
	"github.com/good-winter/cookingapp/server/internal/api"
	"github.com/good-winter/cookingapp/server/internal/store"
```

- [ ] **Step 6: 对真实服务冒烟**

```bash
cd server && go run ./cmd/api
```

另开一个终端：

```bash
curl -s -H "Authorization: Bearer dev-token-user-1" http://127.0.0.1:8080/api/v1/me
```

预期：返回 `u_1` 的 JSON，`preferences.avoidFoods` 为 `[]`。

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/api/v1/me
```

预期：`401`。

- [ ] **Step 7: 提交**

```bash
git add server/
git commit -m "feat(server): 路由装配与 GET /me"
```

---

## Task 9: GET /preferences/options

**Files:**
- Create: `server/internal/api/options.go`, `server/internal/api/options_test.go`
- Modify: `server/internal/api/router.go`

**Interfaces:**
- Consumes: `api.Handler`、`store.OptionsStore`
- Produces: `(h *Handler) GetOptions(c *gin.Context)`

- [ ] **Step 1: 写失败的测试**

`server/internal/api/options_test.go`：

```go
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type fakeOptions struct{ opts models.PreferenceOptions }

func (f fakeOptions) Options(_ context.Context) (models.PreferenceOptions, error) {
	return f.opts, nil
}

func TestGetOptionsReturnsDictionaries(t *testing.T) {
	h := &Handler{
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: fakeOptions{opts: models.PreferenceOptions{
			DietModes:  []models.Option{{Code: "normal", Label: "正常人"}},
			Crowds:     []models.Option{{Code: "pregnant", Label: "孕妇"}},
			AvoidFoods: []models.Option{{Code: "pork", Label: "猪肉"}},
		}},
	}
	r := testRouterWith(h)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/preferences/options", nil)
	req.Header.Set("Authorization", "Bearer t")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d", w.Code)
	}
	var got models.PreferenceOptions
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("响应不是合法 PreferenceOptions: %v", err)
	}
	if len(got.DietModes) != 1 || got.DietModes[0].Label != "正常人" {
		t.Errorf("dietModes 不符: %+v", got.DietModes)
	}
	if len(got.AvoidFoods) != 1 || got.AvoidFoods[0].Code != "pork" {
		t.Errorf("avoidFoods 不符: %+v", got.AvoidFoods)
	}
}
```

- [ ] **Step 2: 在 me_test.go 中补 testRouterWith**

把 `me_test.go` 里的 `testRouter` 改为基于一个新的通用函数，便于其他测试复用：

```go
func testRouterWith(h *Handler) *gin.Engine {
	return NewRouter(config.Config{Env: "development"}, h)
}

func testRouter(t *testing.T) *gin.Engine {
	t.Helper()
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {
				ID: "u_1", Nickname: "美食家", AvatarText: "美", Timezone: "Asia/Shanghai",
				Preferences: models.NewPreferences("normal", []string{"pregnant"}, nil),
			},
		}},
		Tokens: fakeTokens{valid: map[string]string{"dev-token-user-1": "u_1"}},
	})
}
```

- [ ] **Step 3: 运行测试确认失败**

```bash
cd server && go test ./internal/api/ -v -run TestGetOptions
```

预期：404（路由未注册）。

- [ ] **Step 4: 实现**

`server/internal/api/options.go`：

```go
package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
)

func (h *Handler) GetOptions(c *gin.Context) {
	opts, err := h.Options.Options(c.Request.Context())
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}
	c.JSON(http.StatusOK, opts)
}
```

在 `router.go` 的 `v1` 组内补一行：

```go
		v1.GET("/preferences/options", h.GetOptions)
```

- [ ] **Step 5: 运行测试确认通过**

```bash
cd server && go test ./internal/api/ -v
```

预期：全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add server/
git commit -m "feat(server): GET /preferences/options 选项字典"
```

---

## Task 10: PUT /me/preferences

**Files:**
- Create: `server/internal/api/preferences.go`, `server/internal/api/preferences_test.go`
- Modify: `server/internal/api/router.go`

**Interfaces:**
- Consumes: `api.Handler`、`store.UserStore`、`store.OptionsStore`
- Produces: `(h *Handler) PutPreferences(c *gin.Context)`

校验规则：`dietMode` 必须属于 `dietModes` 字典；`crowds` 与 `avoidFoods` 的每个值必须属于对应字典。任一非法 → `400 INVALID_PARAMETER`，`details.invalid` 列出非法值。

- [ ] **Step 1: 写失败的测试**

`server/internal/api/preferences_test.go`：

```go
package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/models"
)

func newPrefsRouter() *gin.Engine {
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {ID: "u_1", Nickname: "美食家", AvatarText: "美",
				Timezone: "Asia/Shanghai", Preferences: models.NewPreferences("normal", nil, nil)},
		}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
		Options: fakeOptions{opts: models.PreferenceOptions{
			DietModes:  []models.Option{{Code: "normal"}, {Code: "vegetarian"}},
			Crowds:     []models.Option{{Code: "pregnant"}, {Code: "fitness"}},
			AvoidFoods: []models.Option{{Code: "pork"}, {Code: "cilantro"}},
		}},
	})
}

func putPrefs(t *testing.T, body string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodPut, "/api/v1/me/preferences", strings.NewReader(body))
	req.Header.Set("Authorization", "Bearer t")
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	newPrefsRouter().ServeHTTP(w, req)
	return w.Code, w.Body.String()
}

func TestPutPreferencesAcceptsValidPayload(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"vegetarian","crowds":["pregnant"],"avoidFoods":["pork"]}`)
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", code, body)
	}
	var got models.Preferences
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("响应不是合法 Preferences: %v", err)
	}
	if got.DietMode != "vegetarian" || len(got.Crowds) != 1 {
		t.Errorf("返回的偏好不符: %+v", got)
	}
}

func TestPutPreferencesRejectsUnknownDietMode(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"吃素","crowds":[],"avoidFoods":[]}`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 dietMode 应返回 400 INVALID_PARAMETER，实际 %d %s", code, body)
	}
}

func TestPutPreferencesRejectsUnknownCrowd(t *testing.T) {
	code, body := putPrefs(t, `{"dietMode":"normal","crowds":["宇航员"],"avoidFoods":[]}`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 crowd 应返回 400，实际 %d %s", code, body)
	}
}

func TestPutPreferencesAcceptsEmptyArrays(t *testing.T) {
	code, _ := putPrefs(t, `{"dietMode":"normal","crowds":[],"avoidFoods":[]}`)
	if code != http.StatusOK {
		t.Fatalf("空数组是合法输入，期望 200，实际 %d", code)
	}
}

func TestPutPreferencesRejectsMalformedJSON(t *testing.T) {
	code, body := putPrefs(t, `{这不是 JSON`)
	if code != http.StatusBadRequest || !strings.Contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法 JSON 应返回 400，实际 %d %s", code, body)
	}
}
```

在该文件 import 块补 `"github.com/gin-gonic/gin"`。

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/api/ -v -run TestPutPreferences
```

预期：404（路由未注册）。

- [ ] **Step 3: 实现**

`server/internal/api/preferences.go`：

```go
package api

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type preferencesRequest struct {
	DietMode   string   `json:"dietMode"`
	Crowds     []string `json:"crowds"`
	AvoidFoods []string `json:"avoidFoods"`
}

func (h *Handler) PutPreferences(c *gin.Context) {
	var req preferencesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"请求体不是合法 JSON", nil)
		return
	}

	ctx := c.Request.Context()
	dict, err := h.Options.Options(ctx)
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	invalid := map[string]any{}
	if !inOptions(req.DietMode, dict.DietModes) {
		invalid["dietMode"] = req.DietMode
	}
	if bad := unknownValues(req.Crowds, dict.Crowds); len(bad) > 0 {
		invalid["crowds"] = bad
	}
	if bad := unknownValues(req.AvoidFoods, dict.AvoidFoods); len(bad) > 0 {
		invalid["avoidFoods"] = bad
	}
	if len(invalid) > 0 {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"偏好取值不在允许的字典内", map[string]any{"invalid": invalid})
		return
	}

	prefs := models.NewPreferences(req.DietMode, req.Crowds, req.AvoidFoods)
	userID := c.GetString(middleware.ContextUserID)

	if err := h.Users.UpdatePreferences(ctx, userID, prefs); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
			return
		}
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, prefs)
}

func inOptions(code string, opts []models.Option) bool {
	for _, o := range opts {
		if o.Code == code {
			return true
		}
	}
	return false
}

func unknownValues(values []string, opts []models.Option) []string {
	out := []string{}
	for _, v := range values {
		if !inOptions(v, opts) {
			out = append(out, v)
		}
	}
	return out
}
```

在 `router.go` 的 `v1` 组内补一行：

```go
		v1.PUT("/me/preferences", h.PutPreferences)
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd server && go test ./internal/api/ -v
```

预期：全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add server/
git commit -m "feat(server): PUT /me/preferences 全量替换与字典校验"
```

---

## Task 11: GET /recipes/recommend

**Files:**
- Create: `server/internal/api/recipes.go`, `server/internal/api/recipes_test.go`
- Modify: `server/internal/api/router.go`

**Interfaces:**
- Consumes: `api.Handler`、`store.RecipeStore`、`store.UserStore`、`recommend.Rank`、`recommend.Page`
- Produces: `(h *Handler) GetRecommend(c *gin.Context)`；响应体 `{"items": [...], "nextCursor": string|null}`

- [ ] **Step 1: 写失败的测试**

`server/internal/api/recipes_test.go`：

```go
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/good-winter/cookingapp/server/internal/models"
)

type fakeRecipes struct{ recipes []models.Recipe }

func (f fakeRecipes) ListRecipes(_ context.Context) ([]models.Recipe, error) {
	return f.recipes, nil
}

func newRecipesRouter() *gin.Engine {
	return testRouterWith(&Handler{
		Users: fakeUsers{user: map[string]models.User{
			"u_1": {ID: "u_1", Preferences: models.NewPreferences("normal", []string{"fitness"}, nil)},
		}},
		Tokens: fakeTokens{valid: map[string]string{"t": "u_1"}},
		Recipes: fakeRecipes{recipes: []models.Recipe{
			{ID: "r_1", Name: "白灼西兰花", IsVegetarian: true, Crowds: []string{"fitness"}, AvoidTags: []string{}},
			{ID: "r_2", Name: "红烧肉", IsVegetarian: false, Crowds: []string{}, AvoidTags: []string{"pork"}},
			{ID: "r_3", Name: "番茄炒蛋", IsVegetarian: true, Crowds: []string{}, AvoidTags: []string{}},
		}},
	})
}

func getRecommend(t *testing.T, query string) (int, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/recipes/recommend"+query, nil)
	req.Header.Set("Authorization", "Bearer t")
	w := httptest.NewRecorder()
	newRecipesRouter().ServeHTTP(w, req)
	return w.Code, w.Body.String()
}

func TestRecommendReturnsRankedItems(t *testing.T) {
	code, body := getRecommend(t, "")
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d，body=%s", code, body)
	}
	var got struct {
		Items []models.Recipe `json:"items"`
	}
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("响应不是合法分页结构: %v", err)
	}
	// 命中的 r_1 应排最前；未命中人群的按 id 升序 r_2、r_3。
	if len(got.Items) != 3 || got.Items[0].ID != "r_1" {
		t.Fatalf("排序不符，实际 %+v", got.Items)
	}
	if got.Items[1].ID != "r_2" || got.Items[2].ID != "r_3" {
		t.Fatalf("同分应按 id 升序，实际 %+v", got.Items)
	}
}

func TestRecommendNextCursorIsNullWhenExhausted(t *testing.T) {
	_, body := getRecommend(t, "")
	if !contains(body, `"nextCursor":null`) {
		t.Fatalf("没有下一页时 nextCursor 必须是 null，实际 body=%s", body)
	}
}

func TestRecommendPaginates(t *testing.T) {
	code, body := getRecommend(t, "?limit=1")
	if code != http.StatusOK {
		t.Fatalf("期望 200，实际 %d", code)
	}
	var got struct {
		Items      []models.Recipe `json:"items"`
		NextCursor *string         `json:"nextCursor"`
	}
	if err := json.Unmarshal([]byte(body), &got); err != nil {
		t.Fatalf("解析失败: %v", err)
	}
	if len(got.Items) != 1 || got.NextCursor == nil {
		t.Fatalf("期望 1 条且带 nextCursor，实际 %+v", got)
	}

	code2, body2 := getRecommend(t, "?limit=1&cursor="+*got.NextCursor)
	if code2 != http.StatusOK {
		t.Fatalf("第二页期望 200，实际 %d，body=%s", code2, body2)
	}
	var got2 struct {
		Items []models.Recipe `json:"items"`
	}
	_ = json.Unmarshal([]byte(body2), &got2)
	if len(got2.Items) != 1 || got2.Items[0].ID == got.Items[0].ID {
		t.Fatalf("第二页应返回不同的菜谱，实际 %+v", got2.Items)
	}
}

func TestRecommendRejectsBadLimit(t *testing.T) {
	code, body := getRecommend(t, "?limit=abc")
	if code != http.StatusBadRequest || !contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非数字 limit 应返回 400，实际 %d %s", code, body)
	}
}

func TestRecommendRejectsBadCursor(t *testing.T) {
	code, body := getRecommend(t, "?cursor=不是游标")
	if code != http.StatusBadRequest || !contains(body, "INVALID_PARAMETER") {
		t.Fatalf("非法游标应返回 400，实际 %d %s", code, body)
	}
}
```

在该文件 import 块补 `"github.com/gin-gonic/gin"`。

- [ ] **Step 2: 运行测试确认失败**

```bash
cd server && go test ./internal/api/ -v -run TestRecommend
```

预期：404（路由未注册）。

- [ ] **Step 3: 实现**

`server/internal/api/recipes.go`：

```go
package api

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/good-winter/cookingapp/server/internal/httputil"
	"github.com/good-winter/cookingapp/server/internal/middleware"
	"github.com/good-winter/cookingapp/server/internal/models"
	"github.com/good-winter/cookingapp/server/internal/recommend"
	"github.com/good-winter/cookingapp/server/internal/store"
)

type recommendResponse struct {
	Items      []models.Recipe `json:"items"`
	NextCursor *string         `json:"nextCursor"`
}

func (h *Handler) GetRecommend(c *gin.Context) {
	limit := recommend.DefaultLimit
	if raw := c.Query("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 {
			httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
				"limit 必须是正整数", map[string]any{"limit": raw})
			return
		}
		limit = parsed
	}

	ctx := c.Request.Context()
	userID := c.GetString(middleware.ContextUserID)

	prefs, err := h.Users.GetPreferences(ctx, userID)
	if errors.Is(err, store.ErrNotFound) {
		httputil.Abort(c, http.StatusNotFound, httputil.CodeUserNotFound, "用户不存在", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	recipes, err := h.Recipes.ListRecipes(ctx)
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	ranked := recommend.Rank(recipes, prefs)

	items, nextCursor, err := recommend.Page(ranked, limit, c.Query("cursor"))
	if errors.Is(err, recommend.ErrInvalidCursor) {
		httputil.Abort(c, http.StatusBadRequest, httputil.CodeInvalidParameter,
			"游标非法或已失效，请丢弃后重新请求", nil)
		return
	}
	if err != nil {
		httputil.Abort(c, http.StatusInternalServerError, httputil.CodeInternalError,
			"服务器内部错误", nil)
		return
	}

	c.JSON(http.StatusOK, recommendResponse{Items: items, NextCursor: nextCursor})
}
```

在 `router.go` 的 `v1` 组内补一行：

```go
		v1.GET("/recipes/recommend", h.GetRecommend)
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd server && go test ./internal/api/ -v
```

预期：全部 PASS。

- [ ] **Step 5: 全量测试与静态检查**

```bash
cd server && go test ./... && go vet ./...
```

预期：全部 PASS，vet 无输出。

- [ ] **Step 6: 提交**

```bash
git add server/
git commit -m "feat(server): GET /recipes/recommend 推荐接口"
```

---

## Task 12: 端到端冒烟与交付

**Files:**
- Create: `server/README.md`

**Interfaces:**
- Consumes: 全部前序任务
- Produces: 可交给前端的联调说明

- [ ] **Step 1: 起服务**

```bash
cd server && go run ./cmd/api
```

- [ ] **Step 2: 逐条验证 Phase 1 四个接口**

```bash
# 1. 用户信息
curl -s -H "Authorization: Bearer dev-token-user-1" http://127.0.0.1:8080/api/v1/me

# 2. 选项字典
curl -s -H "Authorization: Bearer dev-token-user-1" http://127.0.0.1:8080/api/v1/preferences/options

# 3. 推荐（默认偏好）
curl -s -H "Authorization: Bearer dev-token-user-1" http://127.0.0.1:8080/api/v1/recipes/recommend

# 4. 改成素食 + 忌口海鲜，推荐应当变化
curl -s -X PUT -H "Authorization: Bearer dev-token-user-1" -H "Content-Type: application/json" \
  -d '{"dietMode":"vegetarian","crowds":["pregnant"],"avoidFoods":["seafood"]}' \
  http://127.0.0.1:8080/api/v1/me/preferences
curl -s -H "Authorization: Bearer dev-token-user-1" http://127.0.0.1:8080/api/v1/recipes/recommend
```

预期：第 4 步的推荐里**不应出现** `红烧肉`、`清蒸鲈鱼`、`香煎鸡胸肉` 等非素食项；应出现 `番茄炒蛋`、`白灼西兰花`。

- [ ] **Step 3: 验证开发期调试 token**

```bash
curl -s -H "X-Debug-Token: dev-token-user-2" http://127.0.0.1:8080/api/v1/me
```

预期：返回 `u_2`（健身狂人B）而非 `u_1`。

- [ ] **Step 4: 写 server/README.md**

内容需包含：如何创建数据库、如何配置 `.env`、如何启动、四个接口的 curl 样例、三个测试 token 的对应关系、以及「本机 MySQL 8.0 已在运行」这一前提。

- [ ] **Step 5: 提交**

```bash
git add server/README.md
git commit -m "docs(server): 后端启动与接口联调说明"
```

- [ ] **Step 6: 把进度同步给前端评审者**

在 `docs/API_CONTRACT.md` 的评审意见一节末尾追加一节 `## 六、后端进度`，写明：

- Phase 1 四个接口已实现并通过 `go test ./...`
- 本地启动方式与三个测试 token
- **Phase 0 种子数据已就绪**（这是评审者最关心的阻塞点）——菜谱库 12 条，含热量与营养比例
- 菜谱营养数据为演示估值，需替换为可靠来源
- 剩余待办：Phase 2（识别 + 统计）、Phase 3（社区），以及 Phase 2 才用得到的 `timezone` 字段已入库但尚未被消费

然后提交：

```bash
git add docs/API_CONTRACT.md
git commit -m "docs: 同步后端 Phase 1 进度到契约"
```

---

## 完成标准

全部任务完成后应满足：

- `cd server && go test ./...` 全部通过
- `cd server && go vet ./...` 无输出
- `/api/v1/me`、`/api/v1/preferences/options`、`/api/v1/recipes/recommend`、`/api/v1/me/preferences` 四个接口对真实 MySQL 可用
- 未带 token 的请求返回 `401 UNAUTHORIZED`
- `avoidFoods` 为空时返回 `[]` 而非 `null`
- 素食模式下推荐结果不含荤菜
- `docs/API_CONTRACT.md` 已升到 v2 且是仓库中唯一的契约文件

## 本计划不覆盖的内容

- Phase 2：`POST /recognitions`、`/stats/summary`、`/stats/records`
- Phase 3：社区四个接口与两个删除端点
- 生产鉴权（JWT / 手机号登录）
- 图片存储与上传
- 限流、监控、部署
