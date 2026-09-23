# 后端 Phase 1 修复说明

> 分支 `firsttext`，基于 `feature/backend-phase0-1`（`862245e`）。
> 日期：2026-09-24。由前端侧提交，供后端评审。
>
> 这次改动**没有**动 `docs/API_CONTRACT.md` 正文 —— 契约是你的文档，
> 涉及契约的疑问都列在下面等你定，我没有单方面改。

Phase 1 的四个接口整体质量很高：错误码与契约逐个字符一致、JSON 形状（含
`null` / `[]` / 缺省）全部对得上、`recommend` 包纯函数化让核心逻辑能脱离数据库
测、`go vet` 干净。下面三处是真问题，另外几处是加固。

---

## 一、需要你先决策的一件事

### `X-Debug-Token` 到底该不该覆盖 `Authorization`

**这是本次唯一改动了你原设计语义的地方，请重点看。**

契约 `docs/API_CONTRACT.md:526`：

> 后端另支持 `X-Debug-Token` 请求头**覆盖**，仅当后端 APP_ENV=development 时生效，
> 可用于在设置页做运行时切换用户，免重启。

同一份契约 `:518` 又要求前端实现「注入 Authorization 的请求拦截器」。

你原来的实现是 `Authorization` 优先、仅在它为空时才回退到调试头
（`internal/middleware/auth.go`），并且 `auth_test.go` 里有一条
`TestAuthPrefersAuthorizationOverDebugHeader` 固定该行为，README 也照此描述。
你的注释写了理由：「避免调试头意外覆盖真实身份」——这个顾虑本身成立。

但两者按字面组合后：前端装了拦截器 → 每个请求都带 `Authorization` →
调试头**永远不生效** → 契约承诺的「设置页切换用户免重启」是空头支票。

两条路，得择一：

| 方案 | 代价 |
|---|---|
| **（本次采取）** 开发期让调试头覆盖，与契约 `:526` 一致 | 你的原语义被反转；生产环境不受影响（`allowDebugHeader=false` 时完全忽略该头） |
| 保留你的原语义，改契约 `:526` 的措辞为「仅作为替代方案」 | 「设置页切换用户」这个功能得换实现方式，例如前端在切换用户时不带 `Authorization`，或用一个只注入真实 token 的独立 dio 实例 |

我按契约改了（`firsttext` 上已生效）。**如果你认为原设计更对，请告诉我，我回退代码、你改契约措辞**，这件事不该由我单方面定。

---

## 二、三处真问题

### 1. 过期游标返回 200 而不是 400（契约违约）

契约两处写死了这个行为：`:363`「携带过期游标会返回 `400 INVALID_PARAMETER`」，
`:685` 处置栏「已采纳」。

原实现的游标载荷只有 `{Score, ID}`，**没有任何偏好指纹**，所以服务端在原理上
无法判断游标是不是旧偏好签发的。`recipes.go` 里唯一映射为 400 的分支只有
「格式解不开」。

**用种子数据可复现地验证**（u_1，`limit=10`）：

```bash
B=http://127.0.0.1:8080/api/v1
T="Authorization: Bearer dev-token-user-1"

# 1. 偏好为空，拿第一页和游标
curl -s -X PUT -H "$T" -H "Content-Type: application/json" \
  -d '{"dietMode":"normal","crowds":[],"avoidFoods":[]}' $B/me/preferences
curl -s -H "$T" "$B/recipes/recommend?limit=10"      # 记下 nextCursor

# 2. 改偏好，让 r_11（凉拌黄瓜，带 fitness 标签）得 1 分
curl -s -X PUT -H "$T" -H "Content-Type: application/json" \
  -d '{"dietMode":"normal","crowds":["fitness"],"avoidFoods":[]}' $B/me/preferences

# 3. 带上刚才那个游标
curl -s -H "$T" "$B/recipes/recommend?limit=10&cursor=<旧游标>"
```

**结果**：返回 200，第二页从 `r_12` 开始且 `nextCursor` 为 `null`。
于是 `r_11` 第一页没出现、第二页也没出现，**永久消失**，而前端以为已经取完。
同时真正的头两名 `r_03` / `r_06` 被排在旧顺序的第 3、6 位 —— 用户改了偏好，
看到的推荐却没变。这正是契约 `:324` 点名要避免的「错乱的序列」。

**修复**：游标增加一个偏好指纹字段（`recommend.PreferencesFingerprint`），
指纹不符即返回 `ErrStaleCursor` → 400 `INVALID_PARAMETER`。

指纹做了归一化：`crowds` / `avoidFoods` 内部先排序、`nil` 与空切片等价。
所以前端换个顺序提交同一组偏好**不会**误判失效。

顺带说明一个**不需要**担心的情况：定位下一页用的是排序键比较而非偏移量，
因此菜谱库增删条目时游标仍然落在正确位置，不会重复或漏页。真正需要判失效的
只有「排序键本身变了」，也就是偏好变更这一种。跨用户使用游标也无害——游标
不携带任何权限，且用了别人的游标会因指纹不符被拒（除非两人偏好完全相同，
那结果本来就一样）。

### 2. `crowds` / `avoidFoods` 有重复值时打成 500

`preferences.go` 校验时不去重，`mysql_user.go` 逐条 `INSERT`，而
`user_preference_crowds` 的主键是 `(user_id, crowd)`（`0001_schema.sql:47`）。
所以

```bash
curl -s -X PUT -H "$T" -H "Content-Type: application/json" \
  -d '{"dietMode":"normal","crowds":["fitness","fitness"],"avoidFoods":[]}' $B/me/preferences
```

会撞主键 1062 → `INTERNAL_ERROR` 500。前端只要有个小 bug 重复推一个值就能触发。

**修复**：去重收口在 `models.NewPreferences`。选这个位置有两个理由：它是所有偏好
数据的唯一入口（写入与读取都走它）；而且它同时保证**回显的偏好与落库的偏好逐项
一致**，否则前端本地状态会和库里存的分叉。顺序保留首次出现。

### 3. `X-Debug-Token`

见第一节。

---

## 三、运维加固

| 项 | 原因 |
|---|---|
| `0002_seed.sql` 全部改 `INSERT IGNORE` | `0001` 建表带 `IF NOT EXISTS` 因而天然幂等，`0002` 却是裸 INSERT。迁移执行器是「先执行、后记录」，进程若在两步之间挂掉，下次启动会重跑整份文件 → 撞主键 → `log.Fatalf` → **服务再也起不来**。现在两份文件都可重复执行。刻意不用 `ON DUPLICATE KEY UPDATE`：种子数据的期望是「已存在就保持现状」，不做隐式覆盖。 |
| `main.go` 改「先 bind 再 Serve」 | 原来在 goroutine 里 `ListenAndServe`，端口被占用时会与 `log.Printf("服务已启动...")` 抢跑，**让一次失败的启动看起来像成功了**。同步 `net.Listen` 后这行日志出口时端口一定已经拿到。 |
| `main.go` 补 `ReadHeaderTimeout: 10s` | 不设时，一个只连不发的客户端就能一直占着连接，攒够数量即拖垮服务（Slowloris）。 |
| `PUT /me/preferences` 补 64 KiB 请求体上限 | 不加限制时 `ShouldBindJSON` 会一直读到客户端声称的长度。超限与 JSON 格式错误分开报，别让人去猜成因。 |
| `mysql_user.go` 去掉 `VALUES(diet_mode)` | 该函数自 MySQL 8.0.20 起被弃用。值本来就在手上，再传一次即可，对各版本 MySQL 都成立。 |

### 我故意没做的一件事

**没有给迁移加事务。** 它本来在我的加固清单里，但 MySQL 的 DDL 会隐式提交，
事务包不住含 `CREATE TABLE` 的 `0001`，只能给出虚假的原子性保证；而真正的补救
（幂等）已经做了。理由写进 `migrate.go` 的注释了。如果你有 DB 环境认为值得加，
建议只对纯 DML 的迁移加，并且要实际验证 `0001` 那种含 DDL 的文件不会被 `COMMIT`
搞坏 —— 我这台机器没有可用凭据，验不了，所以没有盲改。

---

## 四、我没动的，建议你处置

1. **`limit` 越界的处理方式自相矛盾。** 同一个参数两套策略：非数字或 `< 1`
   返回 400，`> 50` 却静默截断到 `MaxLimit`，且响应里没有任何字段提示被截断。
   契约对 `limit` 的合法区间与越界语义**完全没定义**（只有 `limit=20` / `limit=10`
   两个示例）。这是契约缺口，建议补一句再定实现。
2. **契约 `:51` 与 `:574` 自相矛盾。** `:51` 说「除健康检查外所有接口要求请求头」，
   `:574` 说 `/preferences/options` 是「静态数据、**无复杂鉴权**」。实现按 `:51` 办了。
   建议把 `:574` 改成「无业务依赖」之类，否则后来人会以为它免鉴权。
3. **枚举非法时该 400 还是 422。** 契约 `:131` 给 422 的定义是「参数格式正确但无法
   处理」，`{"dietMode":"吃素"}` 恰好符合；实现返回 400 `INVALID_PARAMETER`。
   `:139-149` 只给了 `code` 的语义、没给 code→status 的绑定，所以 400 也站得住。
   建议明确「INVALID_PARAMETER 恒为 400」。
4. **`PUT /me/preferences` 的缺省字段行为未定义，实现内部还不一致。**
   `dietMode` 缺失 → 400，但报错文案是「偏好取值不在允许的字典内」，对「字段缺失」
   是误导；`crowds` / `avoidFoods` 缺失 → 静默当作 `[]`。建议契约写明三者是否必填。
5. **`u_2` 的 `avatarText` 与契约示例不符。** 契约 `:269` 的示例是 `"B"`，
   种子数据 `0002_seed.sql:23` 是 `'健'`。契约没有规定该字段的生成规则，
   但前端若照契约示例写死预期就会不一致。
6. **`diet_modes` 字典的「数据驱动」只对了一半。** `0002_seed.sql` 顶部注释与契约
   `:346` 都宣传「新增选项只需加行、前端无需发版」，但筛选语义硬编码在
   `recommend.go` 的 `"vegetarian"` 字面量里 —— 往 `diet_modes` 加一行 `vegan`，
   它下发给前端了、用户能选，**但对推荐结果毫无影响**，且是静默的。
   要么在契约里写明「新增饮食模式需后端发版」，要么做成可配置。
7. **两处不可达的 404 分支。** `preferences.go`（`UpdatePreferences` 返 ErrNotFound）
   与 `recipes.go`（`GetPreferences` 返 ErrNotFound）：MySQL 实现里前者是 upsert
   永不返回、后者无偏好行时返回默认值；而 token 由 `api_tokens` 外键保证指向真实
   用户（`ON DELETE CASCADE`）。所以这两个分支从 HTTP 层进不去。无害，但属死代码。
8. **契约 `:86` 的游标样例有误导性。** `eyJvZmZzZXQiOjIwfQ` 解出来是 `{"offset":20}`，
   是偏移式语义，而实现是 `{s,i,p}` 的位置式游标。契约明说游标不透明（`:80`），
   不构成违约，但这个样例会让人误以为游标基于 offset。建议换个中性样例。

---

## 五、验证状态（请补完最后一格）

已做：

- `go vet ./...` 干净；`go test ./...` 全过。
- **变异测试**：把每处修复临时改坏，确认对应用例真的变红，再还原。三处修复
  都有真实测试兜底，不是「测试通过」就交差。
- 新增的游标失效用例在 **handler 与纯函数两层**都有（`recipes_test.go`、
  `recommend_test.go`），并配了一条「偏好未变时游标照常可用」的反向用例，
  防止把正常翻页一起误杀。

**没做，需要你补**：

- **`internal/store` 的 MySQL 集成测试全程被跳过**（本机没有 `server/.env`）。
  因此「重复值原本会打成 500」与「`INSERT IGNORE` 确实幂等」这两条**是代码推断，
  没有在真库上跑过**。请在你的环境跑一次：

  ```bash
  cd server && go test ./...        # .env 就位后 store 的集成测试会真正连接
  ```

  另外建议手工验一次迁移幂等：在迁移已记录的情况下，手动删掉
  `schema_migrations` 里 `0002_seed.sql` 那行再启动，服务应当正常起来而不是撞主键。

---

## 六、破坏性变更

- **游标格式变了**（多了指纹字段 `p`）。此前签发的游标一律返回 400
  `INVALID_PARAMETER`。目前还没有部署、前端也没接，实际影响为零，但如果你本地
  存了旧游标直接测会看到 400。
- **`recommend.Page` 签名变了**，多了 `prefs models.Preferences` 参数。刻意把
  `prefs` 收进签名而不是让调用方自己传指纹，是为了让「忘记绑定」这件事无法发生。
  除 `recipes.go` 外没有别的调用方。
- `internal/middleware` 的 `Auth` 行为变了（见第一节）。
