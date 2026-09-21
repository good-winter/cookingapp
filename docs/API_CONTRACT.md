# cookingapp 后端接口契约设计

日期: 2026-09-21
状态: v2 已定稿（前端评审意见 10 条已全部处置，见文末）

---

## 背景

cooking_app 是一个双人协作的 Flutter 项目：前端由合作者编写，后端由本文档作者负责。

本文档撰写时（2026-09-21 白天），前端是一个纯 UI 原型：dio、flutter_tts、
image_picker、shared_preferences 虽已在 pubspec.yaml 声明但零引用，也不存在任何
fromJson / toJson。因此当时不存在事实上的接口契约，本文档从零设计。

**状态更新（契约 v2）：** 前端随后落地了设置页、深色模式与 i18n，上述两项描述已过时 ——
shared_preferences 已用于本地持久化，fromJson / toJson 也已存在。契约正文只描述
「接口应为何」，不再断言前端现状；前端实况以「前端改造清单」一节为准。

后端起点的状态是全新起步，无任何现有代码。

## 目标

定义前端与后端之间的完整接口契约，覆盖七个对接点（用户信息、菜谱推荐、AI 图像识别、帖子列表、发布动态、统计与历史、饮食偏好），并明确前端需要配合的改造。

## 已确认的决策

| # | 决策 | 选择 |
|---|---|---|
| 1 | 账号体系 | 预留鉴权，后端先发固定测试 token |
| 2 | 偏好存储与推荐计算 | 全后端：偏好入库，推荐服务端计算 |
| 3 | AI 识别接口形态 | 同步返回 |
| 4 | 统计数据来源 | 识别结果自动入账 |
| 5 | 社区范围 | 推荐流 + 关注关系（不含同城） |
| 6 | 营养数据来源 | 方案 (c)：先查菜谱库，查不到再退回模型估算 |
| 7 | 用户时区 | 现在就加入用户表 |
| 8 | 评论 | 本期只提供 commentCount，不做评论接口 |

## 通用约定

### 基础

- Base URL: `/api/v1`
- 传输: JSON，`Content-Type: application/json`；文件上传用 `multipart/form-data`
- 字段命名: camelCase（与 Dart 侧一致，避免映射表）
- 热量单位: 统一 kcal，类型为 number
- 响应包: 不包裹 `{code, message, data}` 外壳，直接使用 HTTP 状态码 + 资源本体。目的是让前端 dio 拦截器能按状态码直接分流，模型层不必逐层解包。

### 鉴权

除健康检查外，所有接口要求请求头：

```
Authorization: Bearer <token>
```

本期后端签发三个固定测试 token，各映射一个种子用户：

```
dev-token-user-1  →  美食家（主测试账号）
dev-token-user-2  →  健身狂人B
dev-token-user-3  →  厨房小白C
```

之所以需要多个 token：关注是用户之间的动作，只有一个用户时前端无法验证关注流是否生效。

**实现要求**: token → userId 的解析必须作为真实的中间件实现，即使当前 token 是写死的字符串。这样将来替换为真实 JWT 时，前端无需改动。

### 时间

所有时间字段使用 ISO 8601 带时区偏移，例如 `2026-09-21T14:30:00+08:00`。

后端只返回绝对时间。「刚刚」「1小时前」这类相对表述由前端根据 `createdAt` 自行计算。前端现有代码中 `time: '刚刚'` 是写死的字符串，必须替换。

### 分页

统一使用游标式分页：

```
GET /resource?cursor=<opaque>&limit=20
```

响应：

```json
{ "items": [], "nextCursor": "eyJvZmZzZXQiOjIwfQ" }
```

`nextCursor` 为 null 或缺失表示没有下一页。

选择游标式而非页码式的原因：社区推荐流会持续插入新帖，页码式在翻页时会出现重复或漏帖。代价是无法跳转到指定页，但信息流场景不需要该能力。

**排序键。** 游标分页的正确性依赖一个稳定的全序，否则翻页会重复或漏记录。约定如下：

| 接口 | 排序键 |
|---|---|
| 按时间倒序的信息流（`/posts`、`/stats/records`） | `(createdAt DESC, id DESC)` |
| `/recipes/recommend` | `(匹配人群数 DESC, id ASC)` |

`/stats/records` 尤其要注意：同一自然日可能有多餐，`date` 是天粒度、不足以定序，
必须让 `createdAt` 参与排序键。

### 错误格式

```json
{
  "error": {
    "code": "RECIPE_NOT_FOUND",
    "message": "菜谱不存在",
    "details": {}
  }
}
```

- `code` 是稳定的机器可读枚举，前端可据此做条件分支。
- `message` 是可直接展示给用户的中文文案。
- `details` 为可选的补充信息，无内容时返回空对象。

状态码语义：

| 状态码 | 含义 |
|---|---|
| 200 | 成功 |
| 201 | 创建成功（仅 POST /posts） |
| 400 | 请求参数错误 |
| 401 | 未认证或 token 失效 |
| 403 | 已认证但无权限 |
| 404 | 资源不存在 |
| 409 | 状态冲突 |
| 413 | 上传文件过大 |
| 422 | 语义错误（参数格式正确但无法处理） |
| 429 | 触发限流 |
| 500 | 服务端错误 |

本期定义的 `error.code` 取值：

| code | 触发场景 |
|---|---|
| UNAUTHORIZED | token 缺失或无效 |
| FORBIDDEN | 无权操作该资源 |
| USER_NOT_FOUND | 用户不存在 |
| RECIPE_NOT_FOUND | 菜谱不存在 |
| POST_NOT_FOUND | 帖子不存在 |
| IMAGE_NOT_RECOGNIZED | 无法从图中识别出食材 |
| IMAGE_TOO_LARGE | 图片超过大小上限 |
| UNSUPPORTED_IMAGE_FORMAT | 图片格式不支持 |
| INVALID_PARAMETER | 请求参数不合法 |
| RATE_LIMITED | 触发限流 |
| INTERNAL_ERROR | 服务端内部错误 |

### 幂等性

点赞与关注使用 PUT / DELETE，而非 POST。这样天然幂等：重复调用不报错，返回当前状态。前端在弱网重试时无需特殊处理。

### 上传限制

| 项 | 值 |
|---|---|
| 单张图片大小上限 | 5 MB |
| 接受格式 | jpg / jpeg / png / webp |

超限返回 `413 IMAGE_TOO_LARGE`，格式不符返回 `400 UNSUPPORTED_IMAGE_FORMAT`。

前端必须在**上传前**压缩（image_picker 的 maxWidth / imageQuality），
否则移动网络下传原图会撞上识别接口 30 秒的超时。

## 数据模型

### 枚举编码

所有枚举值使用英文码，不使用中文。

| 字段 | 前端当前值 | 接口值 |
|---|---|---|
| dietMode | '正常人' / '素食主义' | normal / vegetarian |
| crowds | '孕妇' '学生' '健身人群' '老人' '运动员' | pregnant student fitness elderly athlete |
| avoidFoods | '猪肉' '牛肉' '海鲜' '香菜' '辛辣' | pork beef seafood cilantro spicy |

原因：'正常人' 是展示文案而非语义名称，文案调整会导致接口破坏性变更；中文作为 URL 查询参数需要额外编码，易引入编码 bug。

代价评估：前端需要新增一张 code → 中文 label 映射表（约 10 行）。由于推荐逻辑已迁移到服务端，前端原本用于匹配的中文比较逻辑本就要删除，剩余中文仅用于显示，因此当前迁移成本很低。

**哪些枚举由服务端下发、哪些由前端本地维护，边界如下：**

| 枚举 | 来源 | 说明 |
|---|---|---|
| dietMode / crowds / avoidFoods | 服务端下发（`/preferences/options`） | 数据驱动，后端可能增删选项 |
| freshness / nutritionSource / MealRecord.source | 前端本地 l10n | 闭集，不随数据变化 |

前一类走接口是为了兑现「新增选项无需发版」；后一类本就是固定集合，
放进接口只会徒增一次请求，应写在前端的 label 映射表里。

### User

```json
{
  "id": "u_1",
  "nickname": "美食家",
  "avatarText": "美",
  "timezone": "Asia/Shanghai",
  "preferences": {
    "dietMode": "normal",
    "crowds": ["pregnant", "fitness"],
    "avoidFoods": ["pork", "cilantro"]
  }
}
```

`timezone` 为 IANA 时区标识，用于统计接口按用户本地时区切分自然日。

### Recipe

```json
{
  "id": "r_1",
  "name": "番茄炒蛋",
  "emoji": "🍲",
  "imageUrl": null,
  "cookTimeMinutes": 10,
  "isVegetarian": true,
  "crowds": ["pregnant", "student"],
  "avoidTags": [],
  "calories": 180,
  "nutrition": {
    "carbsPercent": 50,
    "proteinPercent": 25,
    "fatPercent": 25
  }
}
```

相对前端现有 MockRecipe 的变化：

- `cookTimeMinutes` 为数字，替代 `'10分钟'` 字符串。
- `isVegetarian` 为明确布尔字段，替代原先 `tags.contains('素食')` 的字符串匹配。
- `calories` 与 `nutrition` 为新增字段。现有菜谱数据完全没有热量和营养信息，而识别自动入账与统计功能都依赖它们。
- `imageUrl` 为可空新增字段，前端有图用图、无图回退到 emoji。

### MealRecord

```json
{
  "id": "meal_1",
  "date": "2026-09-20",
  "createdAt": "2026-09-20T12:30:00+08:00",
  "recipeId": "r_01",
  "recipeName": "番茄炒蛋",
  "emoji": "🍲",
  "calories": 180,
  "source": "recognition"
}
```

- `source` 取值 `recognition`，为将来可能的手动记录预留。
- `createdAt` 是**全序排序键**，游标分页依赖它（见「分页」一节的排序键约定）。
  `date` 是天粒度，同日多餐无法定序，不能单独作为排序依据。
- `recipeId` 可空：命中菜谱库时有值，模型估算（未命中）时为 null。
  没有它，「从历史记录点进菜谱详情」就实现不了。

### Post

```json
{
  "id": "p_1",
  "author": {
    "id": "u_2",
    "nickname": "健身狂人B",
    "avatarText": "B",
    "tags": ["fitness", "athlete"]
  },
  "createdAt": "2026-09-21T12:00:00+08:00",
  "content": "求问：健身完吃这个热量超了吗？",
  "imageEmoji": "🥗",
  "imageUrl": null,
  "hashtags": ["减脂餐", "低卡"],
  "likeCount": 12,
  "commentCount": 89,
  "likedByMe": false,
  "followedAuthor": false
}
```

相对前端现有 Post 的变化：

- `userName` / `userAvatar` / `userTag` 收拢为 `author` 对象。
- `likes` → `likeCount`，`isLiked` → `likedByMe`。点赞是每个用户各自的视角，缺少 `byMe` 语义时前端无法判断当前用户是否点过赞。
- `time` → `createdAt`（绝对时间）。
- 新增 `followedAuthor`，用于渲染关注按钮状态。
- `author.tags` 是**数组**，复用 crowds 枚举（pregnant / student / fitness / elderly / athlete）。
  用数组而非单值，是因为用户可勾选多个人群标签，后端不做「取第一个」这类武断截断；
  前端渲染 `tags.first`，数组为空时不渲染标签。

## 接口清单

共 13 个接口。

### A. 用户与偏好

#### 1. GET /me

返回当前用户对象（含 preferences）。

将偏好放在 `/me` 下返回，是为了让首页只需 2 次请求（`/me` + `/recipes/recommend`），而无需 3 次。

#### 2. PUT /me/preferences

请求体：

```json
{
  "dietMode": "vegetarian",
  "crowds": ["pregnant"],
  "avoidFoods": ["pork"]
}
```

响应：200 + 更新后的 preferences。

使用 PUT 全量替换而非 PATCH 的原因：前端偏好弹窗的交互是「编辑完整偏好后一次性提交」，三个字段始终同时提交。PUT 语义更直白，后端也无需处理字段缺省。

**前端流程要求**：保存成功后必须重新请求 `/recipes/recommend`，**并丢弃已持有的游标**。
现有实现是本地立即重算，接入接口后需改为显式重新拉取。

推荐结果由服务端按当前偏好计算，偏好一变，此前签发的游标即失效 —— 继续用它翻页会得到错乱的序列。

**中间态约定：** 「保存成功但重拉推荐失败」时，前端必须显式报错并提供重试入口，
不得静默展示「偏好已更新、推荐还是旧的」这种不一致状态。

#### 3. GET /preferences/options

```json
{
  "dietModes": [
    { "code": "normal", "label": "正常人" },
    { "code": "vegetarian", "label": "素食主义" }
  ],
  "crowds": [
    { "code": "pregnant", "label": "孕妇" }
  ],
  "avoidFoods": [
    { "code": "pork", "label": "猪肉" }
  ]
}
```

现有选项列表硬编码在前端常量中。改为接口下发后，新增忌口项属后端数据变更，无需发版。

**缓存策略：每次启动拉取一次，内存缓存，不落盘。** 这样既避免每次进设置页都请求，
也不会因为持久化缓存让新选项在客户端长期不出现 —— 落盘缓存会让「无需发版」这个卖点失效。
响应体积很小，每次启动拉一次的代价可以忽略。

### B. 菜谱推荐

#### 4. GET /recipes/recommend?limit=10&cursor=

```json
{ "items": [], "nextCursor": null }
```

**请求不携带任何偏好参数。** 偏好已存储在服务端，由后端读取并计算推荐。前端传入偏好参数会被忽略。

排序键为 `(匹配人群数 DESC, id ASC)`。偏好变更后此前签发的 `cursor` 失效，
前端必须丢弃并从头请求；携带过期游标会返回 `400 INVALID_PARAMETER`。

### C. AI 识别

#### 5. POST /recognitions

`multipart/form-data`，字段名 `image`。

```json
{
  "id": "rec_1",
  "ingredients": [
    { "name": "番茄", "freshness": "fresh" },
    { "name": "鸡蛋", "freshness": "fresh" }
  ],
  "isVegetarian": true,
  "matchedRecipe": null,
  "nutrition": {
    "calories": 180,
    "carbsPercent": 50,
    "proteinPercent": 25,
    "fatPercent": 25
  },
  "nutritionSource": "recipe",
  "recordId": "meal_1"
}
```

字段说明：

- `nutritionSource` 取值 `recipe`（来自菜谱库，可信）或 `estimated`（模型估算，不准确）。前端必须依据此字段决定是否展示「营养数据为估算值」提示。缺少该字段会导致估算值被当作准确值展示。
- `recordId` 指向本次识别自动入账产生的 MealRecord。识别即入账，没有独立的手动记账接口。
- `matchedRecipe` 为命中的菜谱对象，未命中时为 null。
- `ingredients[].name` 为中文显示名，前端可直接展示。
- `ingredients[].freshness` 取值 `fresh`（新鲜）/ `normal`（一般）/ `spoiled`（不新鲜）。

识别流程按方案 (c) 实现：

1. 视觉模型识别出食材与菜名。
2. 用菜名查询菜谱库。命中则使用库中的营养数据，`nutritionSource = "recipe"`。
3. 未命中则使用模型估算值，`nutritionSource = "estimated"`。

错误：

- 400 图片格式不支持
- 413 图片过大
- 422 IMAGE_NOT_RECOGNIZED 无法从图中识别出食材

注意 422 是错误响应，不是返回 200 带空数组。

**前端要求**：`POST /recognitions` 的 dio 超时必须单独放宽到 30 秒以上，使用全局默认值会误判超时。

### D. 统计

#### 6. GET /stats/summary?from=2026-09-07&to=2026-09-20

```json
{
  "from": "2026-09-07",
  "to": "2026-09-20",
  "todayCalories": 1800,
  "dailyCalories": [
    { "date": "2026-09-07", "calories": 1800 },
    { "date": "2026-09-08", "calories": 0 }
  ],
  "nutritionPercent": {
    "carbsPercent": 50,
    "proteinPercent": 25,
    "fatPercent": 25
  },
  "estimatedRatio": 0.2
}
```

约束：

- `dailyCalories` 必须补齐范围内每一天，无记录的日期返回 0，不得跳过。前端柱状图按数组下标取日期标签，数量不匹配会导致数组越界。
- `todayCalories` 由后端按用户 timezone 计算，不由前端从日期串推导。时区跨日边界是最易出错的位置。
- 「本周平均」由前端从 `dailyCalories` 自行计算，接口不提供。
- `estimatedRatio`（0–1）表示这一份聚合里，营养数据来自模型估算的比例。
  识别接口用 `nutritionSource` 区分可信与估算，但聚合会把两种来源混在一起 ——
  没有这个字段，前端就无法再提示「含估算数据」，该提示逻辑会在聚合层静默失效。
- `from` / `to` 可省略，省略时默认返回「今天往前 13 天」共 14 天，与前端现有图表一致。

#### 7. GET /stats/records?cursor=&limit=

```json
{ "items": [], "nextCursor": null }
```

元素结构见 MealRecord。

### E. 社区

#### 8. GET /posts?feed=recommend|following&cursor=&limit=20

```json
{ "items": [], "nextCursor": null }
```

元素结构见 Post。

`feed=following` 返回当前用户关注的人的帖子流，供「关注」tab 使用。前端现有三个 tab 复用同一列表，需改为「推荐」与「关注」分别请求不同 feed。

#### 9. POST /posts

请求体：

```json
{
  "content": "...",
  "hashtags": ["快手菜"],
  "imageEmoji": "🍱",
  "imageUrl": null
}
```

响应：201 + 完整帖子对象（含服务端生成的 id 与 createdAt）。

前端现有的本地时间戳 id 生成逻辑必须替换为使用响应中的服务端 id。

#### 10. 点赞

```
PUT    /posts/{id}/like   → 200 {"likeCount": 129, "likedByMe": true}
DELETE /posts/{id}/like   → 200 {"likeCount": 128, "likedByMe": false}
```

返回最新计数，使前端在乐观更新失败时可直接用响应覆盖为正确值，无需额外查询。

#### 11. 关注

```
PUT    /users/{id}/follow   → 200 {"following": true}
DELETE /users/{id}/follow   → 200 {"following": false}
```

### F. 删除类端点

设置页的「数据管理」需要清除数据，以下是配套接口。

#### 12. DELETE /stats/records

清除当前用户的**全部**饮食记录，返回 `204`，无响应体。

#### 13. DELETE /posts/{id}

删除自己的帖子，返回 `204`。删除他人帖子返回 `403 FORBIDDEN`，帖子不存在返回 `404 POST_NOT_FOUND`。

**本期不做：** 评论相关端点（评论数据模型尚未定义），因此「我的发言」也一并推迟到评论模型落地之后。

## 前端改造清单

### 需要新增

- 网络层 —— 需要 dio 实例、base URL 配置、注入 Authorization 的请求拦截器、解析 error 结构的响应拦截器。
- 超时配置 —— 全局 10 秒；POST /recognitions 单独 30 秒。
- 相对时间格式化工具 —— 由 createdAt 计算「刚刚 / 1小时前」。
- 枚举 label 映射表 —— 英文码 → 中文显示文案，扩展到 `lib/l10n/enum_labels.dart`。
  需覆盖三组服务端下发枚举（dietMode / crowds / avoidFoods）与三组闭集
  （freshness / nutritionSource / MealRecord.source），边界见「枚举编码」一节。
- **开发期 token 注入** —— 用 `--dart-define=API_TOKEN=dev-token-user-1` 编译期注入，
  token 不落盘。建议在 `.vscode/launch.json` 配三个启动项，分别对应三个测试用户。
  后端另支持 `X-Debug-Token` 请求头覆盖，**仅当后端 APP_ENV=development 时生效**，
  可用于在设置页做运行时切换用户，免重启。

### 逐文件改动

| 文件 | 改动 |
|---|---|
| lib/features/cooking/data/mock_recipes.dart | **整个文件删除** —— 菜谱数据改由 GET /recipes/recommend 提供 |
| lib/features/cooking/services/recipe_recommender.dart | **整个文件删除** —— 推荐逻辑已迁到服务端（决策 #2）。这个文件连同它那份测试一并移除 |
| lib/features/cooking/models/recipe.dart | 加 fromJson；补 calories / nutrition 字段，cookTimeMinutes 由字符串改数字，补 isVegetarian 与 imageUrl |
| lib/models/user_preferences.dart | 枚举值改英文码；删除 crowdOptions / avoidOptions 常量，改从 GET /preferences/options 获取 |
| lib/core/storage/preference_storage.dart | 偏好改为服务端存储后本文件角色要重定 —— 要么删除，要么降级为「离线只读缓存」。契约规定 PUT /me/preferences 是唯一写入口 |
| lib/providers/preference_provider.dart | 由本地 StateNotifier 改为异步 provider，读走 GET /me、写走 PUT /me/preferences |
| lib/features/cooking/screens/cooking_screen.dart | userName 改从 GET /me 获取；拍照 onTap 接入 image_picker 并调用 POST /recognitions；推荐列表改调接口 |
| lib/features/cooking/widgets/preference_modal.dart | 选项改从接口获取；保存改调 PUT；成功后**重新拉推荐并丢弃游标**；补 loading 与失败重试（见中间态约定） |
| lib/features/community/models/post.dart | 字段重构，见 Post 模型；author 收拢为对象，新增 tags 数组 |
| lib/features/community/screens/community_screen.dart | 删除 _posts 假数据；**TabController 由 length: 3 改为 2**（决策 #5 砍掉同城，这处遗漏了）；「关注」tab 改为请求 feed=following；点赞/关注改调接口并实现乐观更新与失败回滚；发帖改用服务端返回 id |
| lib/features/community/screens/create_post_screen.dart | _submitPost 由 Navigator.pop 回传 Map 改为调用 POST /posts；图片选择接入 image_picker |
| lib/features/community/widgets/post_card.dart | 字段名跟随模型改动（likes→likeCount、isLiked→likedByMe）；time 改为由 createdAt 计算的相对时间 |
| lib/features/statistics/screens/statistics_screen.dart | 删除四组假常量；改拉 GET /stats/summary 与 GET /stats/records；顶栏写死的「2026年9月」改为动态；依据 estimatedRatio 展示「含估算数据」提示 |
| lib/features/settings/screens/data_management_screen.dart | 「清除」目前是占位，接上 DELETE /stats/records 与 DELETE /posts/{id} |
| lib/l10n/enum_labels.dart | 扩展 label 映射，覆盖服务端下发枚举与闭集枚举 |
| lib/core/utils/greeting.dart | 已重构为返回 DayPart 枚举、与语言解耦，**不需要改动** |
| lib/features/settings/** 其余 | 本地设置类功能，与接口无关，本期不改动 |

### 两条旧说明已撤回

- ~~test/widget_test.dart 已失效，接入接口前应先删除或重写~~ —— **撤回。**
  前端已重写该文件，连同新增测试共 49 个用例全过，是接入接口期间的回归网。不要删。
- ~~pubspec.lock 处于被修改状态~~ —— **已解决。** 根因是开发机把 `PUB_HOSTED_URL`
  指向了国内镜像，而镜像的包版本滞后于 pub.dev，导致同一份 pubspec.yaml 在两边解析出
  不同版本（实测差异 85 行 vs 4 行）。已改为直连 pub.dev，lock 与前端侧对齐。
  另：开发机 Flutter 已由 3.41.4 升到 3.47.2，与项目 .metadata 记录的 revision 一致。

## 分期计划

### Phase 0（后端）：骨架与种子数据

没有种子数据前端无法联调。需要准备：

- 三个测试 token 对应的用户，用户表需包含 timezone 字段。
- 带营养数据的菜谱库。现有前端 mock 仅 6 条且无热量字段，需重新整理。
- 若干条帖子。

### Phase 1：用户与偏好 + 推荐（接口 1/2/3/4）

打通「拉用户 → 改偏好 → 推荐变化」链路。前端在本期建立网络层。

若需最快验证网络层连通性，GET /preferences/options 是最简单的调用（静态数据、无复杂鉴权）。

### Phase 2：识别 + 统计（接口 5/6/7）

完成「拍照 → 识别 → 入账 → 统计」产品主线。本期前端需接入相机，是前端工作量最大的一期，建议提前对排期。

### Phase 3：社区（接口 8/9/10/11）

社区域独立，不影响主线，且现有 UI 已有骨架，属纯改造，排在最后不阻塞任何事项。

排序理由：识别与统计是产品核心卖点，优先级最高；社区虽独立但改造难度最低，垫后不影响进度。

## 未决事项

- **菜谱库的权威来源。** Phase 0 会先交付一份 12 条的种子菜谱库（含热量与营养比例），
  但**营养数值是演示用的估值，不是营养学准确数据**，上线前必须替换为可靠来源。
  这份种子数据足以让接口 4 与接口 5 的联调先跑起来，不再阻塞前端。
- 生产环境鉴权方案（手机号/第三方登录）未定，本期仅使用测试 token。

---

# 前端评审意见

> 本节由前端补充，不属于契约正文。日期：2026-09-21
> 这里是完整清单；发给合作者的消息只需挑最紧急的几条，不必全盘甩过去。

## 一、契约需要澄清或补充的（10 条）

### 🔴 会阻塞前端开发，动手前需要定

**1. `Post.author.tag` 是单值，但 `User.preferences.crowds` 是数组 —— 语义未定义**

`/me` 可能返回 `"crowds": ["pregnant", "fitness"]`，而 `Post.author.tag` 只有一个值。
用户选了多项时渲染哪一个？契约没有写。
→ 需要明确规则（取第一个？还是用户表另立「主标签」？）

> **处置：已采纳。** 改为 `author.tags` **数组**，后端不做「取第一个」这类武断截断。
> 前端渲染 `tags.first`，为空则不渲染标签。见「Post」模型。

**2. `/stats/records` 的游标分页缺少唯一排序键 —— 会导致翻页重复或漏记录**

`MealRecord` 只有 `date`（`"2026-09-20"`，天粒度）和 `id`，**没有 `createdAt`**。
同一天记三餐就是三条 `date` 完全相同的记录。游标分页要求稳定的全序，
只按 `date` 排序时同日记录的先后顺序未定义。
→ 建议加 `createdAt`，排序键用 `(date DESC, id DESC)`

> **处置：已采纳，排序键略作调整。** `MealRecord` 加 `createdAt`。
> 排序键定为 `(createdAt DESC, id DESC)` 而非 `(date DESC, id DESC)` ——
> `date` 与 `createdAt` 在本场景下同序，但直接用 `createdAt` 更直接，
> 且能与 `/posts` 共用同一条排序约定。见「分页」一节。

**3. 图片大小上限没有定义，但前端必须知道才能实现**

契约定义了 `413 IMAGE_TOO_LARGE`，却没写上限是多少 MB。
前端必须在**上传前**压缩（image_picker 的 `maxWidth` / `imageQuality`），
否则用户在移动网络传原图会撞 30 秒超时。
→ 需要一个明确数字（建议 5MB）

> **处置：已采纳，取值 5 MB。** 格式限定 jpg / jpeg / png / webp。见「上传限制」一节。

**4. 三个固定 token 有了，但前端开发期怎么切换没说**

契约说明了多发 token 是为了验证关注流。但前端没有登录界面 ——
开发期改代码常量、重编译一次切一个用户，不现实。另外 token 存哪也没说。
→ 需要定一个方案（debug 面板 / 环境变量 / 构建参数）

> **处置：已采纳。** 用构建参数：`--dart-define=API_TOKEN=...`，token 不落盘，
> 建议配三个 .vscode/launch.json 启动项。另外后端会支持 `X-Debug-Token` 请求头覆盖，
> **仅当后端 APP_ENV=development 时生效** —— 这样若前端想做成设置页里的运行时切换，
> 不必重编译。见「前端改造清单 · 需要新增」。

### 🟡 影响功能完整性

**5. `/stats/summary` 的 `nutritionPercent` 无法区分数据来源**

接口 5 用 `nutritionSource` 区分 `recipe` / `estimated`，前端据此提示「营养数据为估算值」。
但 summary 聚合时把两种来源混在一起，前端**没有任何字段**能判断这个比例里
有多少来自估算 —— 提示逻辑直接失效。
→ 聚合时带 `estimatedRatio`，或明确说明聚合只统计 `recipe` 来源

> **处置：已采纳，取第一种做法。** `/stats/summary` 返回 `estimatedRatio`（0–1）。
> 这条指出了原契约的一处自相矛盾：接口 5 用 `nutritionSource` 区分来源，
> 聚合时却把这个区分丢掉了，前端提示逻辑会在聚合层静默失效。见接口 6。

**6. 枚举 label 映射表不完整**

契约要求前端新增「英文码 → 中文文案」映射，但只覆盖了
`dietMode` / `crowds` / `avoidFoods`。还漏三个同样需要显示文案的：

- `freshness`: `fresh` / `normal` / `spoiled`
- `nutritionSource`: `recipe` / `estimated`
- `MealRecord.source`: `recognition`

> **处置：已采纳，但划清了边界。** 这三组是**闭集**，不随数据变化，
> 因此不进 `/preferences/options`，而是写进前端本地的 label 映射表。
> 服务端只下发会增删的那三组（dietMode / crowds / avoidFoods）。见「枚举编码」一节。

**7. `MealRecord` 建议加可空的 `recipeId`**

现在只有 `recipeName`，将来「从历史记录点进菜谱详情」做不到。
加字段成本几乎为零；等要用了再改就要动表。

> **处置：已采纳。** `MealRecord` 加可空 `recipeId`。见「MealRecord」模型。

### 🟢 建议补充的约定

**8. 偏好变更后必须丢弃已有游标**

`/recipes/recommend` 是服务端按当前偏好算出的排序。翻页中途改偏好，游标就失效了。
契约已说「保存后必须重新请求」，建议补上「并丢弃游标」。

> **处置：已采纳。** 接口 2 与接口 4 均已写明；携带过期游标返回 `400 INVALID_PARAMETER`。

**9. `PUT /me/preferences` 成功但重拉推荐失败的中间态**

两段式流程（保存 → 重新拉推荐）的中间失败没有定义。此时前端处于
「偏好已变、推荐还是旧的」。需要约定：显式报错 + 允许重试，
而不是静默展示不一致的数据。

> **处置：已采纳。** 已写进接口 2 的「中间态约定」：必须显式报错并提供重试入口。

**10. `/preferences/options` 的缓存策略与「无需发版」有张力**

契约说选项下发的价值是「新增忌口项无需发版」，同时又说「前端应在启动时拉取一次并缓存」。
但缓存恰恰会让新选项在客户端不出现，反而需要发版或加过期策略。
→ 建议明确缓存策略（每次启动拉、不落盘？还是设 TTL？）

> **处置：已采纳，取「每次启动拉取一次，内存缓存，不落盘」。** 这条指出了原文的自相矛盾：
> 一边说下发选项是为了「无需发版」，一边又说启动时缓存 —— 落盘缓存恰恰会让新选项
> 在客户端长期不出现，把那个卖点抵消掉。见接口 3。

## 二、需要后端补充的接口

**缺少删除类端点。** 设置页的「数据管理」需要清除统计数据与社区行为，
但契约里没有对应接口。建议补：

- `DELETE /stats/records` —— 清除饮食记录
- `DELETE /posts/{id}` —— 删除自己的帖子
- 以及「我的发言」对应的接口（取决于评论数据模型，本期契约未定义）

> **处置：已采纳前两条。** 新增接口 12 `DELETE /stats/records` 与接口 13 `DELETE /posts/{id}`。
> 「我的发言」依赖尚未定义的评论模型，一并推迟 —— 本期不做评论，只保留 `commentCount`。

## 三、需要后端知悉的前端约束

**枚举值不能参与 i18n。** 契约第 148-158 行的枚举编码方案（`normal` /
`vegetarian` / `pork` …）是正确的方向。补充一点：前端目前的
`lib/models/user_preferences.dart` 里，中文常量**同时是显示文案和匹配主键**
（`recipe_recommender.dart` 靠 `prefs.dietMode == '素食主义'` 判断，
mock 菜谱的标签必须字面相等才匹配得上）。

所以前端做全量 i18n 时，**必须先完成 code/label 分离**，不能直接给 UI 套翻译层。
否则饮食偏好的过滤逻辑会静默失效 —— 不报错，但推荐结果不对。

## 四、仓库协作事项

1. **`pubspec.lock` 已变动。** 前端为实现设置页的语言切换，新增了
   `flutter_localizations` 与 `intl`。这个文件之前被提过容易冲突，建议尽早提交。

2. **`lib/l10n/generated/` 需要一并提交。** 那是 `flutter gen-l10n` 生成的代码
   （3 个文件），Flutter 在非合成包模式下要求提交，否则拉下来编译不过。

3. **不要删除 `test/widget_test.dart`。** 契约里写的「已失效，应先删除或重写」
   已经过时 —— 前端已重写，目前连同新增测试共 48 个用例全过。接入接口期间
   它是回归网。

> **处置：已采纳。** 原契约里「应删除该文件」的建议已撤回，见「两条旧说明已撤回」。

4. **契约里描述前端现状的几处已过时**（写文档时的快照早于前端改动）：
   - 「shared_preferences 零引用」→ 已用于本地持久化
   - 「全项目没有任何 fromJson / toJson」→ 已有
   - 「逐文件改动」表基于旧文件树，遗漏了 `features/cooking/` 下新增的
     `data/`、`models/`、`services/` 三层
   - 社区 `TabController(length: 3)` 需改为 2（决策 #5 已砍掉同城，文档漏了这处 UI 改动）

> **处置：已采纳。** 「前端改造清单」已按合并后的真实文件树重写，
> 并补上了 `TabController` 这处遗漏；`features/cooking/` 下新增的
> `data/` / `models/` / `services/` 三层也已反映（其中前两层中 `data/` 与
> `services/recipe_recommender.dart` 属于要**删除**的文件）。

## 五、想确认的一件事

**Phase 0 的种子数据大概什么时候能给？**

契约里写了「没有种子数据前端无法联调」，需要三样：三个 token 对应的用户
（用户表含 timezone）、**带营养数据的菜谱库**、若干条帖子。

其中**菜谱库是最重的一块**，而且契约把它列在「未决事项」——
来源与录入方式都还没定。但它卡着接口 4（推荐）和接口 5（识别），
而这两个恰好是排在最高优先级的产品主线。

在它就绪之前，前端只能对着契约空转。这个时间点决定前端怎么排期。
