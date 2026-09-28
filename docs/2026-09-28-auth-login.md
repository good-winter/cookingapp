# 手机号验证码登录 —— 接口补充契约

日期：2026-09-28
状态：**已实现并实测通过**，供评审
关系：`docs/API_CONTRACT.md` 的**扩张**，不是实现既有条款

---

## 为什么会多出这份文档

`API_CONTRACT.md` 第 591 行把这件事明确挂起来了：

> - 生产环境鉴权方案（手机号/第三方登录）未定，本期仅使用测试 token。

本次把它落地：**用户输入自己的手机号 → 收验证码 → 登录**。所以这不是照契约实现，
契约里没有这两个接口，`users` 表也没有 `phone` 列。

已确认的决策：

| # | 决策 | 选择 |
|---|---|---|
| 1 | 分工 | 前后端一起做（本文档即后端改动的评审说明） |
| 2 | 验证码发送 | 开发期固定码，不真发短信；发送器是可替换实现 |
| 3 | 未注册手机号 | 自动注册并登录 |
| 4 | 签发 token 的有效期 | 本期不过期 |
| 5 | 前端编译期 `API_TOKEN` | 保留，但默认值改为空串 |

---

## 一、两个新接口

两者都**免鉴权** —— 它们就是用来换取 token 的，要求带 token 会变成死循环。
Base URL 与通用约定（无响应包裹、camelCase、错误信封）沿用契约正文。

### 1. POST /auth/sms/send

```json
请求  {"phone": "13800138000"}

响应  200
{
  "expiresInSeconds": 300,
  "retryAfterSeconds": 60,
  "devCode": "123456"
}
```

| 字段 | 说明 |
|---|---|
| `expiresInSeconds` | 验证码有效期，供界面提示用 |
| `retryAfterSeconds` | 距下次可重发的秒数。**前端按钮的倒计时必须用它**，不要硬编码 60 —— 窗口由服务端定，两边各写一个数就会漂移 |
| `devCode` | **仅 `APP_ENV=development` 下出现**。生产环境该字段不存在（`omitempty`），且用的是随机码 |

限流是两条独立的规则，都返回 `429 RATE_LIMITED`：

| 规则 | 值 | 超出时的 `details` |
|---|---|---|
| 同号码重发间隔 | 60 秒 | `{"retryAfterSeconds": <剩余秒数>}` |
| 同号码 24 小时发送总量 | 10 条 | 无 |

手机号格式不合法（非 `^1[3-9]\d{9}$`）→ `400 INVALID_PARAMETER`，
`details` 带违规值 `{"phone": "..."}`，与 `PUT /me/preferences` 的既有校验约定一致。

### 2. POST /auth/sms/verify

```json
请求  {"phone": "13800138000", "code": "123456"}

响应  200
{
  "token": "c2e95deb67b8f9c6…",
  "isNewUser": true,
  "user": { …User，结构同 GET /me… }
}
```

流程：取该号码最新一条验证码 → 查有效期与失败次数 → 比对 → 标记已消费 →
按手机号找用户（找不到就**自动注册**）→ 签发随机 token 写入 `api_tokens`。

`isNewUser` 让前端知道这次登录顺带完成了注册，可以给一句「已为你创建账号」。

### 验证码的三条语义

1. **一次性**：校验通过即标记 `consumed_at`，重复使用返回 `400 SMS_CODE_EXPIRED`。
   标记用的是条件更新（`WHERE consumed_at IS NULL`），影响行数为 0 即视为已被
   别的请求抢先消费 —— 所以「一次性」不依赖调用方加锁，连点两次登录按钮
   只会拿到一个 token。
2. **失败次数上限**：同一个码最多试 5 次，超过即作废（返回 `SMS_CODE_EXPIRED`）。
   没有它，6 位码可以被在线枚举。计数由 SQL 自增而非读-改-写，并发猜码不会互相覆盖。
3. **有效期 5 分钟**（`APP_SMS_CODE_TTL` 可调）。

### 错误码

新增两个，已同步进 `API_CONTRACT.md` 的错误码表：

| code | 状态码 | 场景 |
|---|---|---|
| `SMS_CODE_INVALID` | 400 | 验证码错误，可以改一位再试 |
| `SMS_CODE_EXPIRED` | 400 | 验证码不存在、已过期、已用过、或失败次数超限 |

为什么把后四种情形合并成一个码：对用户而言引导是同一句话「请重新获取验证码」，
再细分只会泄漏「这个码存在但已用过」这类信息。而 `SMS_CODE_INVALID` 必须与它分开 ——
「输错了」和「重新获取」要用户做的事完全不同。

复用既有常量：`RATE_LIMITED`（429）、`INVALID_PARAMETER`（400，手机号格式）、
`INTERNAL_ERROR`（500）。

---

## 二、自动注册

号码未注册时直接建号，无需单独的注册接口 —— 登录与注册是同一个入口。

| 字段 | 取值 |
|---|---|
| `id` | `u_` + 8 位随机十六进制 |
| `nickname` | `用户` + 手机号后四位 |
| `avatarText` | 手机号后两位 |
| `timezone` | `Asia/Shanghai` |
| preferences | 插一行默认（`normal` / 空 crowds / 空 avoidFoods） |

昵称取后四位是为了让同一台测试机上注册的多个账号在界面上能区分开；用户进 App 后
可以自己改。

**`models.User` 没有加 `phone` 字段。** 契约里的 User 结构是已定稿的协作基准，
本次不为一个展示字段去动它 —— 手机号由前端存在本地（本来就是用户自己输的）。

注册与「建用户 + 写默认偏好」在一个事务里。偏好行必须一起写：不写的话
`GetPreferences` 会走进「查不到就返回默认值」的分支，结果碰巧一样，
但那个用户会一直没有偏好行。

并发注册同一号码（连点两次登录）由 `users.phone` 的唯一键兜住：后到的那次写
拿到 `ErrDuplicate`，调用方改为复用已存在的用户，而不是把 500 抛给一个
其实已经成功的登录。

---

## 三、对既有代码的改动

### 1. `router.go` 必须重构（这次最容易踩的坑）

原来整个 `/api/v1` 组都挂了鉴权中间件：

```go
v1.Use(middleware.Auth(h.Tokens, cfg.IsDevelopment()))   // 对之后注册的所有路由生效
```

`v1.Use(...)` 影响的是**该组之后注册的全部路由**，所以两个登录接口必须注册在
带中间件的子组之外，否则会变成「要求先登录才能登录」，而报错信息完全指不到这里。
现在长这样：

```go
v1.POST("/auth/sms/send", h.PostSmsSend)      // 免鉴权
v1.POST("/auth/sms/verify", h.PostSmsVerify)

authed := v1.Group("")
authed.Use(middleware.Auth(h.Tokens, cfg.IsDevelopment()))
{ … 原有四个接口 … }
```

`auth_test.go` 里有两条用例专门守这一点（`TestSmsSendDoesNotRequireAuth` /
`TestSmsVerifyDoesNotRequireAuth`）。

### 2. 鉴权中间件一行都没改

登录签发的 token 与三个开发期静态 token 写在同一张 `api_tokens` 表，
共用 `TokenStore.UserIDByToken` 这条查询。契约里「token → userId 必须作为真实
中间件实现，将来换 JWT 时前端无需改动」那条要求，在这里兑现了。

### 3. 新增

| 位置 | 内容 |
|---|---|
| `internal/db/migrations/0003_auth.sql` | `sms_codes` 表 + `users.phone` 列（含唯一键） |
| `internal/auth/sender.go` | `Sender` 接口 + 开发期 `DevSender` |
| `internal/api/auth.go` | 两个 handler |
| `internal/store/mysql_auth.go` | `AuthStore` 的 MySQL 实现 |
| `store.go` | 新增 `AuthStore` 接口、`ErrDuplicate`；`TokenStore` 加 `CreateToken` |
| `config.go` | `APP_SMS_CODE`（默认 `123456`）、`APP_SMS_CODE_TTL`（默认 `5m`） |
| `httputil.go` | 两个新错误码常量 |

### 4. 迁移必须幂等 —— `0003` 里有个不显眼的写法

迁移执行器是「先执行、后记账、不在事务里」的，任何一步失败都不会记账，
下次启动整份重跑。所以 `CREATE TABLE IF NOT EXISTS` 之外，`users.phone` 那条
**不能直接写 `ALTER TABLE ADD COLUMN`**：MySQL 8.0 不支持
`ADD COLUMN IF NOT EXISTS`（那是 MariaDB 的扩展），重跑时会报
`Error 1060 Duplicate column name` 并让服务起不来。

实际写法是用 `information_schema` 守卫 + `PREPARE`/`EXECUTE` 动态 DDL。
已实测：跑完一次后删掉 `schema_migrations` 里那行再跑一次，服务正常启动。

---

## 四、上线前必须补的

1. **真实短信服务商。** 现在只有 `DevSender`（把验证码打进日志）。接入阿里云/
   腾讯云需实现 `auth.Sender` 并在 `auth.NewSender` 里返回它。**在此之前
   `APP_ENV != development` 会拒绝启动** —— 这是刻意的：退回 DevSender 意味着
   生产环境的验证码只写进日志、用户永远收不到，而接口还返回成功。
2. **token 有效期。** 本期 `api_tokens` 没有 `expires_at`，签发的 token 永不过期。
   上线前要加列并在中间件里校验。前端的 401 处理已经就位（见下），所以加这一条
   不需要前端配合。
3. **手机号格式。** 目前只认大陆手机号（`^1[3-9]\d{9}$`），且没有国际区号处理。

---

## 五、前端侧

- token 落盘在 `shared_preferences`（键 `auth_session`）。注意这与契约
  「开发期 token 不落盘」**不冲突**：那条约束针对的是 `--dart-define` 注入的
  测试凭据，用户自己登录换来的 token 必须落盘，否则每次冷启动都要重收验证码。
- `ApiClient.defaultToken` 的默认值由 `dev-token-user-1` 改为**空串**。
  不改的话裸跑 `flutter run` 会静默以该用户登录，登录页根本不出现。
  `.vscode/launch.json` 的四个启动项都显式传了它，开发流程不受影响。
- 路由加了守卫（`/login` 在 ShellRoute 之外，无底部导航栏）；收到 401 时由
  `ApiClient` 的拦截器统一清会话并把用户送回登录页 —— 补上了
  `docs/2026-09-24-frontend-phase1-integration.md` 里记为「未处理」的 auth 生命周期。
- 测试从 48 个增至 81 个。`pumpApp` 默认注入已登录会话：否则路由守卫会把
  既有用例全部踹到登录页，整张回归网一次全红。

---

## 六、实测记录

真库端到端跑过，覆盖：新号自动注册（`isNewUser: true`）、老号直接登录、
签发 token 能访问 `GET /me`、已消费的码复用被拒、60 秒内重发 429 且带
`retryAfterSeconds`、手机号格式 400、验证码错误 400。测试数据已清理，
库内仍是 3 个种子用户 / 3 个 token。

`go test ./...`、`go vet ./...`、`flutter analyze`、`flutter test` 全部通过。
