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

**新增迁移文件时必须让其自身幂等**（建表带 `IF NOT EXISTS`、插数据带
`INSERT IGNORE`）。迁移执行器是「先执行、后记录」且没有事务保护——MySQL 的
DDL 会隐式提交，用事务包住给不了真正的原子性。进程若在执行与记录之间挂掉，
下次启动会重跑整份文件，只有幂等才能保证服务仍然起得来。

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

### 游标与偏好变更

`/recipes/recommend` 签发的游标**绑定了签发它时的那份偏好指纹**。偏好一变
（`PUT /me/preferences` 成功），此前签发的游标立即失效，继续使用会返回
`400 INVALID_PARAMETER`，前端必须丢弃游标后从头请求。

这是契约接口 2/4 的要求：游标若不带偏好信息，服务端无从判断失效，只能顺着
新排序继续翻页，返回一份「新排序 + 旧位置」拼出来的、静默错乱的序列。

指纹对偏好做了归一化（`crowds` / `avoidFoods` 内部排序、nil 与空切片等价），
所以前端换个顺序提交同一组偏好不会误判失效。定位下一页用的是排序键比较而非
偏移量，因此菜谱库增删条目也仍然安全。

### 测试 token

| token | 用户 |
|---|---|
| `dev-token-user-1` | 美食家 |
| `dev-token-user-2` | 健身狂人B |
| `dev-token-user-3` | 厨房小白C |

开发期（`APP_ENV=development`）还可用 `X-Debug-Token` 请求头**覆盖**
`Authorization`，便于在设置页做运行时切换用户、免重编译。

之所以是「覆盖」而不是「仅在没有 Authorization 时生效」：前端会装一个给每个
请求注入 `Authorization` 的拦截器，永远不会有缺失的时候，只在其缺失时生效
等于永不生效。传空白的 `X-Debug-Token` 不算覆盖，会正常回落到 `Authorization`。
生产环境（`allowDebugHeader=false`）完全忽略该请求头。

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
