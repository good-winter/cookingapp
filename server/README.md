# cookingapp 后端

Go + Gin + MySQL 的 REST 服务，实现 `docs/API_CONTRACT.md` 中的 Phase 1 接口。

## 前置条件

- Go 1.25+
- MySQL 8.0（本机 `MySQL80` 服务需处于运行状态）

## 首次启动

**1. 建库**（用 Navicat / Workbench / 命令行均可）：

```sql
CREATE DATABASE IF NOT EXISTS cookingapp
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

**2. 配置凭据**：复制 `.env.example` 为 `.env`，填入自己的 MySQL 密码。

`.env` 已被 `.gitignore` 排除，**不要提交**。`.env.example` 里必须始终保持占位符。

**3. 启动**：

```bash
cd server
go run ./cmd/api
```

启动时会自动执行 `internal/db/migrations/` 下未跑过的迁移（建表 + 种子数据），
已执行过的会跳过，因此重复启动是安全的。

服务默认监听 `:8080`。健康检查：`GET /healthz`（无需鉴权）。

## 测试

```bash
cd server
go test ./...      # 全部
go vet ./...       # 静态检查
```

`internal/store` 的集成测试会连接真实 MySQL（从 `server/.env` 读 `APP_DSN`）；
未设置 `APP_DSN` 时自动跳过，因此在没有数据库的机器上 `go test ./...` 也能通过。

## 已实现的接口

Base URL 为 `/api/v1`，除健康检查外都需要 `Authorization: Bearer <token>`。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/me` | 当前用户 + 饮食偏好 |
| PUT | `/me/preferences` | 全量替换偏好 |
| GET | `/preferences/options` | 选项字典（三组） |
| GET | `/recipes/recommend` | 按服务端偏好算出的推荐，游标分页 |

### 测试 token

| token | 用户 |
|---|---|
| `dev-token-user-1` | 美食家 |
| `dev-token-user-2` | 健身狂人B |
| `dev-token-user-3` | 厨房小白C |

开发期（`APP_ENV=development`）还可用 `X-Debug-Token` 请求头替代
`Authorization`，便于免重编译地切换用户；`Authorization` 优先级更高。

### curl 示例

```bash
B=http://127.0.0.1:8080/api/v1
T="Authorization: Bearer dev-token-user-1"

curl -s -H "$T" $B/me
curl -s -H "$T" $B/preferences/options
curl -s -H "$T" "$B/recipes/recommend?limit=10"

curl -s -X PUT -H "$T" -H "Content-Type: application/json" \
  -d '{"dietMode":"vegetarian","crowds":["pregnant"],"avoidFoods":["seafood"]}' \
  $B/me/preferences
```

## 目录结构

```
server/
├── cmd/api/                 启动装配
└── internal/
    ├── api/                 HTTP 层：路由与 handler
    ├── config/              环境变量加载
    ├── db/                  连接与迁移执行器（migrations/ 内嵌 SQL）
    ├── httputil/            错误码常量与统一错误信封
    ├── middleware/          Bearer 鉴权
    ├── models/              领域模型与 JSON 序列化约定
    ├── recommend/           推荐排序与游标分页（纯函数，无 DB 依赖）
    └── store/               接口定义与 MySQL 实现
```

设计上 **`recommend` 包不依赖 `store`**，只依赖 `models` —— 全项目唯一有真实业务
逻辑的部分因此可以完全脱离数据库做单元测试。

## 尚未实现

- Phase 2：`POST /recognitions`、`/stats/summary`、`/stats/records`
- Phase 3：社区接口与两个删除端点
- 生产鉴权（JWT / 手机号登录）
- 图片存储与上传

## 已知限制

- **菜谱营养数据是演示用估值**，不是营养学准确数据，上线前需替换为可靠来源。
- 用户表的 `timezone` 字段已就位，但 Phase 1 尚未消费它（统计接口才需要）。
