# cookingapp 后端接口契约设计

日期:2026-09-21
状态:待评审

## 背景

`cookingapp` 是一个双人协作的 Flutter 项目:前端由合作者编写,后端由本文档作者负责。

前端目前是一个**纯 UI 原型**,所有数据都是内存里的假数据:

- `dio`、`flutter_tts`、`image_picker`、`shared_preferences` 四个依赖已在 `pubspec.yaml` 声明,但**全项目零引用**。
- 全项目**没有任何 `fromJson` / `toJson`**,模型类只是 UI 用的内存对象。
- 因此不存在任何事实上的接口契约,本文档从零设计。

后端起点的状态是**全新起步,无任何现有代码**。

## 目标

定义前端与后端之间的完整接口契约,覆盖七个对接点(用户信息、菜谱推荐、AI 图像识别、帖子列表、发布动态、统计与历史、饮食偏好),并明确前端需要配合的改造。

## 已确认的决策

| # | 决策 | 选择 |
|---|---|---|
| 1 | 账号体系 | 预留鉴权,后端先发固定测试 token |
| 2 | 偏好存储与推荐计算 | 全后端:偏好入库,推荐服务端计算 |
| 3 | AI 识别接口形态 | 同步返回 |
| 4 | 统计数据来源 | 识别结果自动入账 |
| 5 | 社区范围 | 推荐流 + 关注关系(不含同城) |
| 6 | 营养数据来源 | 方案 (c):先查菜谱库,查不到再退回模型估算 |
| 7 | 用户时区 | 现在就加入用户表 |
| 8 | 评论 | 本期只提供 `commentCount`,不做评论接口 |

## 通用约定

### 基础

- **Base URL:** `/api/v1`
- **传输:** JSON,`Content-Type: application/json`;文件上传用 `multipart/form-data`
- **字段命名:** `camelCase`(与 Dart 侧一致,避免映射表)
- **热量单位:** 统一 `kcal`,类型为 number
- **响应包:** 不包裹 `{code, message, data}` 外壳,直接使用 HTTP 状态码 + 资源本体。目的是让前端 dio 拦截器能按状态码直接分流,模型层不必逐层解包。

### 鉴权

除健康检查外,所有接口要求请求头:

```
Authorization: Bearer <token>
```

本期后端签发**三个固定测试 token**,各映射一个种子用户:

```
dev-token-user-1  →  美食家(主测试账号)
dev-token-user-2  →  健身狂人B
dev-token-user-3  →  厨房小白C
```

之所以需要多个 token:关注是用户之间的动作,只有一个用户时前端无法验证关注流是否生效。

**实现要求:** token → userId 的解析必须作为真实的中间件实现,即使当前 token 是写死的字符串。这样将来替换为真实 JWT 时,前端无需改动。

### 时间

所有时间字段使用 ISO 8601 带时区偏移,例如 `2026-09-21T14:30:00+08:00`。

后端**只返回绝对时间**。「刚刚」「1小时前」这类相对表述由前端根据 `createdAt` 自行计算。前端现有代码中 `time: '刚刚'` 是写死的字符串,必须替换。

### 分页

统一使用游标式分页:

```
GET /resource?cursor=<opaque>&limit=20
```

响应:

```json
{ "items": [], "nextCursor": "eyJvZmZzZXQiOjIwfQ" }
```

`nextCursor` 为 `null` 或缺失表示没有下一页。

选择游标式而非页码式的原因:社区推荐流会持续插入新帖,页码式在翻页时会出现重复或漏帖。代价是无法跳转到指定页,但信息流场景不需要该能力。

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

- `code` 是稳定的机器可读枚举,前端可据此做条件分支。
- `message` 是可直接展示给用户的中文文案。
- `details` 为可选的补充信息,无内容时返回空对象。

状态码语义:

| 状态码 | 含义 |
|---|---|
| 200 | 成功 |
| 201 | 创建成功(仅 `POST /posts`) |
| 400 | 请求参数错误 |
| 401 | 未认证或 token 失效 |
| 403 | 已认证但无权限 |
| 404 | 资源不存在 |
| 409 | 状态冲突 |
| 413 | 上传文件过大 |
| 422 | 语义错误(参数格式正确但无法处理) |
| 429 | 触发限流 |
| 500 | 服务端错误 |

本期定义的 `error.code` 取值:

| code | 触发场景 |
|---|---|
| `UNAUTHORIZED` | token 缺失或无效 |
| `FORBIDDEN` | 无权操作该资源 |
| `USER_NOT_FOUND` | 用户不存在 |
| `RECIPE_NOT_FOUND` | 菜谱不存在 |
| `POST_NOT_FOUND` | 帖子不存在 |
| `IMAGE_NOT_RECOGNIZED` | 无法从图中识别出食材 |
| `IMAGE_TOO_LARGE` | 图片超过大小上限 |
| `UNSUPPORTED_IMAGE_FORMAT` | 图片格式不支持 |
| `INVALID_PARAMETER` | 请求参数不合法 |
| `RATE_LIMITED` | 触发限流 |
| `INTERNAL_ERROR` | 服务端内部错误 |

### 幂等性

点赞与关注使用 `PUT` / `DELETE`,而非 `POST`。这样天然幂等:重复调用不报错,返回当前状态。前端在弱网重试时无需特殊处理。

## 数据模型

### 枚举编码

所有枚举值使用英文码,**不使用中文**。

| 字段 | 前端当前值 | 接口值 |
|---|---|---|
| `dietMode` | `'正常人'` / `'素食主义'` | `normal` / `vegetarian` |
| `crowds` | `'孕妇' '学生' '健身人群' '老人' '运动员'` | `pregnant` `student` `fitness` `elderly` `athlete` |
| `avoidFoods` | `'猪肉' '牛肉' '海鲜' '香菜' '辛辣'` | `pork` `beef` `seafood` `cilantro` `spicy` |

原因:`'正常人'` 是展示文案而非语义名称,文案调整会导致接口破坏性变更;中文作为 URL 查询参数需要额外编码,易引入编码 bug。

代价评估:前端需要新增一张 code → 中文 label 映射表(约 10 行)。由于推荐逻辑已迁移到服务端,前端原本用于匹配的中文比较逻辑本就要删除,剩余中文仅用于显示,因此当前迁移成本很低。

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

`timezone` 为 IANA 时区标识,用于统计接口按用户本地时区切分自然日。

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

相对前端现有 `MockRecipe` 的变化:

- `cookTimeMinutes` 为数字,替代 `'10分钟'` 字符串。
- `isVegetarian` 为明确布尔字段,替代原先 `tags.contains('素食')` 的字符串匹配。
- `calories` 与 `nutrition` 为**新增字段**。现有菜谱数据完全没有热量和营养信息,而识别自动入账与统计功能都依赖它们。
- `imageUrl` 为可空新增字段,前端有图用图、无图回退到 `emoji`。

### MealRecord

```json
{
  "id": "meal_1",
  "date": "2026-09-20",
  "recipeName": "番茄炒蛋",
  "emoji": "🍲",
  "calories": 180,
  "source": "recognition"
}
```

`source` 取值 `recognition`,为将来可能的手动记录预留。

### Post

```json
{
  "id": "p_1",
  "author": {
    "id": "u_2",
    "nickname": "健身狂人B",
    "avatarText": "B",
    "tag": "fitness"
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

相对前端现有 `Post` 的变化:

- `userName` / `userAvatar` / `userTag` 收拢为 `author` 对象。
- `likes` → `likeCount`,`isLiked` → `likedByMe`。点赞是每个用户各自的视角,缺少 `byMe` 语义时前端无法判断当前用户是否点过赞。
- `time` → `createdAt`(绝对时间)。
- 新增 `followedAuthor`,用于渲染关注按钮状态。
- `author.tag` 复用 `crowds` 枚举(pregnant / student / fitness / elderly / athlete),用于渲染用户身份标签。

## 接口清单

共 11 个接口。

### A. 用户与偏好

#### 1. `GET /me`

返回当前用户对象(含 `preferences`)。

将偏好放在 `/me` 下返回,是为了让首页只需 2 次请求(`/me` + `/recipes/recommend`),而无需 3 次。

#### 2. `PUT /me/preferences`

请求体:

```json
{
  "dietMode": "vegetarian",
  "crowds": ["pregnant"],
  "avoidFoods": ["pork"]
}
```

响应:200 + 更新后的 `preferences`。

使用 PUT 全量替换而非 PATCH 的原因:前端偏好弹窗的交互是「编辑完整偏好后一次性提交」,三个字段始终同时提交。PUT 语义更直白,后端也无需处理字段缺省。

前端流程要求:保存成功后必须重新请求 `/recipes/recommend`。现有实现是本地立即重算,接入接口后需改为显式重新拉取。

#### 3. `GET /preferences/options`

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

现有选项列表硬编码在前端常量中。改为接口下发后,新增忌口项属后端数据变更,无需发版。前端应在启动时拉取一次并缓存。

### B. 菜谱推荐

#### 4. `GET /recipes/recommend?limit=10&cursor=`

```json
{ "items": [], "nextCursor": null }
```

**请求不携带任何偏好参数。** 偏好已存储在服务端,由后端读取并计算推荐。前端传入偏好参数会被忽略。

### C. AI 识别

#### 5. `POST /recognitions`

`multipart/form-data`,字段名 `image`。

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

字段说明:

- **`nutritionSource`** 取值 `recipe`(来自菜谱库,可信)或 `estimated`(模型估算,不准确)。前端必须依据此字段决定是否展示「营养数据为估算值」提示。缺少该字段会导致估算值被当作准确值展示。
- **`recordId`** 指向本次识别自动入账产生的 `MealRecord`。识别即入账,没有独立的手动记账接口。
- **`matchedRecipe`** 为命中的菜谱对象,未命中时为 `null`。
- **`ingredients[].name`** 为中文显示名,前端可直接展示。
- **`ingredients[].freshness`** 取值 `fresh`(新鲜)/ `normal`(一般)/ `spoiled`(不新鲜)。

识别流程按方案 (c) 实现:

1. 视觉模型识别出食材与菜名。
2. 用菜名查询菜谱库。命中则使用库中的营养数据,`nutritionSource = "recipe"`。
3. 未命中则使用模型估算值,`nutritionSource = "estimated"`。

错误:

- `400` 图片格式不支持
- `413` 图片过大
- `422 IMAGE_NOT_RECOGNIZED` 无法从图中识别出食材

注意 `422` 是错误响应,不是返回 200 带空数组。

前端要求:`POST /recognitions` 的 dio 超时必须单独放宽到 30 秒以上,使用全局默认值会误判超时。

### D. 统计

#### 6. `GET /stats/summary?from=2026-09-07&to=2026-09-20`

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
  }
}
```

约束:

- **`dailyCalories` 必须补齐范围内每一天**,无记录的日期返回 `0`,不得跳过。前端柱状图按数组下标取日期标签,数量不匹配会导致数组越界。
- **`todayCalories` 由后端按用户 `timezone` 计算**,不由前端从日期串推导。时区跨日边界是最易出错的位置。
- 「本周平均」由前端从 `dailyCalories` 自行计算,接口不提供。
- `from` / `to` 可省略,省略时默认返回「今天往前 13 天」共 14 天,与前端现有图表一致。

#### 7. `GET /stats/records?cursor=&limit=`

```json
{ "items": [], "nextCursor": null }
```

元素结构见 `MealRecord`。

### E. 社区

#### 8. `GET /posts?feed=recommend|following&cursor=&limit=20`

```json
{ "items": [], "nextCursor": null }
```

元素结构见 `Post`。

`feed=following` 返回当前用户关注的人的帖子流,供「关注」tab 使用。前端现有三个 tab 复用同一列表,需改为「推荐」与「关注」分别请求不同 feed。

#### 9. `POST /posts`

请求体:

```json
{
  "content": "...",
  "hashtags": ["快手菜"],
  "imageEmoji": "🍱",
  "imageUrl": null
}
```

响应:**201** + 完整帖子对象(含服务端生成的 `id` 与 `createdAt`)。

前端现有的本地时间戳 id 生成逻辑必须替换为使用响应中的服务端 id。

#### 10. 点赞

```
PUT    /posts/{id}/like   → 200 {"likeCount": 129, "likedByMe": true}
DELETE /posts/{id}/like   → 200 {"likeCount": 128, "likedByMe": false}
```

返回最新计数,使前端在乐观更新失败时可直接用响应覆盖为正确值,无需额外查询。

#### 11. 关注

```
PUT    /users/{id}/follow   → 200 {"following": true}
DELETE /users/{id}/follow   → 200 {"following": false}
```

## 前端改造清单

### 需要新增

1. **网络层**——目前完全不存在。需要 dio 实例、base URL 配置、注入 `Authorization` 的请求拦截器、解析 `error` 结构的响应拦截器。
2. **超时配置**——全局 10 秒;`POST /recognitions` 单独 30 秒。
3. **相对时间格式化工具**——由 `createdAt` 计算「刚刚 / 1小时前」。
4. **枚举 label 映射表**——英文码 → 中文显示文案。

### 逐文件改动

| 文件 | 改动 |
|---|---|
| `lib/models/user_preferences.dart` | 枚举值改英文码;删除 `crowdOptions` / `avoidOptions` 常量,改从 `/preferences/options` 获取 |
| `lib/providers/preference_provider.dart` | 由本地 `StateNotifier` 改为异步 provider,读走 `/me`、写走 `PUT /me/preferences` |
| `lib/features/cooking/screens/cooking_screen.dart` | 删除 `mockRecipes` 与整段本地 filter/sort 逻辑;`userName` 改从 `/me` 获取;拍照 `onTap` 接入 `image_picker` 并调用 `POST /recognitions`。`_getGreeting()` 为纯前端逻辑,保留 |
| `lib/features/cooking/widgets/preference_modal.dart` | 选项改从接口获取;保存改调 PUT;成功后触发推荐重新拉取;补充 loading 与失败提示 |
| `lib/features/community/models/post.dart` | 字段重构,见 `Post` 模型 |
| `lib/features/community/screens/community_screen.dart` | 删除 `_posts` 假数据;「关注」tab 改为请求 `feed=following`;点赞/关注改调接口并实现乐观更新与失败回滚;发帖改用服务端返回 id |
| `lib/features/community/screens/create_post_screen.dart` | `_submitPost` 由 `Navigator.pop` 回传 Map 改为调用 `POST /posts`;图片选择接入 `image_picker` |
| `lib/features/community/widgets/post_card.dart` | 字段名跟随模型改动;`time` 改为相对时间格式化 |
| `lib/features/statistics/screens/statistics_screen.dart` | 删除四组假常量;改拉 `/stats/summary` 与 `/stats/records`;顶栏写死的「2026年9月」改为动态 |
| `lib/features/settings/screens/settings_screen.dart` | 空壳页面,本期不改动 |

### 两项清理

1. `test/widget_test.dart` 已失效。当前执行 `flutter test` 必然失败:测试未包裹 `ProviderScope` 抛出 `Bad state: No ProviderScope found`,且断言的是 `flutter create` 模板遗留的计数器。接入接口前应先删除或重写。
2. `pubspec.lock` 当前处于被修改状态(镜像源由 `pub.dev` 改为 `pub.flutter-io.cn`,且 `clock`、`meta`、`vector_math`、`test_api`、`matcher`、`stack_trace`、`platform` 等包被降级)。协作场景下该文件易产生冲突,应尽早确认基准。

## 分期计划

### Phase 0(后端):骨架与种子数据

没有种子数据前端无法联调。需要准备:

- 三个测试 token 对应的用户,用户表需包含 `timezone` 字段。
- **带营养数据的菜谱库。** 现有前端 mock 仅 6 条且无热量字段,需重新整理。
- 若干条帖子。

### Phase 1:用户与偏好 + 推荐(接口 1/2/3/4)

打通「拉用户 → 改偏好 → 推荐变化」链路。前端在本期建立网络层。
若需最快验证网络层连通性,`GET /preferences/options` 是最简单的调用(静态数据、无复杂鉴权)。

### Phase 2:识别 + 统计(接口 5/6/7)

完成「拍照 → 识别 → 入账 → 统计」产品主线。本期前端需接入相机,是前端工作量最大的一期,建议提前对排期。

### Phase 3:社区(接口 8/9/10/11)

社区域独立,不影响主线,且现有 UI 已有骨架,属纯改造,排在最后不阻塞任何事项。

排序理由:识别与统计是产品核心卖点,优先级最高;社区虽独立但改造难度最低,垫后不影响进度。

## 未决事项

- 菜谱库的具体来源与录入方式未定。
- 生产环境鉴权方案(手机号/第三方登录)未定,本期仅使用测试 token。
