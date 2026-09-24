# 前端 Phase 1 接入：改动说明与不足之处

> 分支 `secondtext`，**基于 `firsttext`**（`2a9c84c`）。日期：2026-09-24。
>
> **范围声明：本分支没有改动 `server/` 下的任何文件。** 后端代码保持合作者的原状，
> 一行未动。需要后端配合的唯一一项（CORS）以补丁形式放在
> `docs/patches/2026-09-24-cors-for-flutter-web.patch`，由他决定是否合并。
>
> 相关的后端修复说明见 `docs/2026-09-24-backend-phase1-fixes.md`（在 `firsttext` 上）。

契约 `docs/API_CONTRACT.md` 的「前端改造清单 → 逐文件改动」（约 533-549 行）
共 17 条，本次处理了其中的 Phase 1 部分。

---

## 一、改动说明：做了什么

一句话：**契约 Phase 1 的目标链路「拉用户 → 改偏好 → 推荐变化」现在通了**，
界面上显示的数据从本地假数据换成了服务端下发的真实数据。

### 1. 网络层（全新）

| 文件 | 作用 |
|---|---|
| `lib/core/network/cooking_api.dart` | 四个接口的抽象。抽成接口而非让 provider 直接依赖 dio，是为了让界面测试能注入替身 |
| `lib/core/network/api_client.dart` | dio 实现。`Authorization` 由拦截器统一注入；`--dart-define` 提供 baseUrl/token/debugToken，token 不落盘（契约要求） |
| `lib/core/network/api_exception.dart` | 契约的错误信封 `{error:{code,message,details}}` → 类型化异常，让「按错误码分支」有唯一落点 |

要点：传输层失败（连不上 / 超时）用**独立的** `NETWORK_ERROR` 码，刻意不混进契约的
`error.code` 集合 —— 那集合描述服务端的判断结果，「服务端说你参数不对」和「你连不上
服务端」该让用户做的事完全不同。连不上时的文案会**点明后端地址**，联调时一眼看出该去
启动后端，而不是猜网络。

### 2. 模型

- 新增 `lib/models/user_profile.dart`（GET /me）、`lib/models/preference_options.dart`（GET /preferences/options）
- 新增 `lib/features/cooking/models/recipe_page.dart`（`items` + `nextCursor`）
- 重写 `lib/features/cooking/models/recipe.dart`：按契约改成数字 `cookTimeMinutes`、
  拆开 `tags` → `crowds` + `isVegetarian`、补 `imageUrl`/`calories`/`nutrition` + `fromJson`
- 重写 `lib/models/user_preferences.dart`：值改为契约的**英文码**

### 3. 状态装配

- `lib/providers/api_providers.dart` — 网络层唯一注入点，测试在此换替身
- `lib/providers/me_provider.dart` — 全 App 唯一持有「当前偏好」的地方。`savePreferences()`
  成功后用**服务端回显**更新状态（不是拿入参当真，否则本地与库里的分叉），随后
  invalidate 推荐
- `lib/providers/recommend_provider.dart` — **本 provider 的 state 就是游标的持有者**。
  偏好一变就 invalidate 它，游标随 state 一起被丢弃，下次从第一页重来。把游标放在
  state 里而不是散在界面字段里，是为了让「丢弃游标」无法被遗漏
- `lib/providers/preference_options_provider.dart` — FutureProvider 天然对上契约
  「每次启动拉一次、内存缓存、不落盘」

### 4. 界面接线

- `cooking_screen.dart` — 昵称与推荐都来自服务端；四态渲染（首屏加载 / 出错 / 空 / 有数据）
- `preference_modal.dart` — 三组选项改从服务端字典读；保存改 `await` PUT +
  失败**不关闭弹窗**、显示错误、可直接重试
- `settings_screen.dart` — 昵称/头像也接 `GET /me`（原来写死 `'美食家'`，那条注释自己
  就写着「接入 GET /me 之后改为从接口读」）。不修的话，用 `dev-token-user-2` 启动时
  首页显示「健身狂人B」而设置页显示「美食家」，看起来像串号
- `l10n/enum_labels.dart` — 三组映射表的键从中文改成英文码（文件注释本就预告了这次迁移）；
  另加 `*Option()` 包装：本地 l10n 优先，映射不到才回退服务端下发的 label

**契约两处硬要求的落地**：

1. 「保存成功后必须重新请求推荐，并丢弃已持有的游标」—— 由 `savePreferences()` 里的
   `invalidate(recommendProvider)` 实现，是结构性的，不靠记得手动清
2. 「中间态约定：保存成功但重拉失败必须显式报错 + 重试入口」—— 推荐区出错时
   **用错误替换列表**而不是叠在旧数据上；偏好弹窗保存失败时不关闭

### 5. 删除的文件

| 文件 | 理由 |
|---|---|
| `lib/features/cooking/data/mock_recipes.dart` | 契约 `:533` 要求整文件删除，菜谱改由接口提供 |
| `lib/features/cooking/services/recipe_recommender.dart` | 契约 `:534` 要求整文件删除，推荐已迁到服务端 |
| `lib/core/storage/preference_storage.dart` | 契约 `:537` 给了「删除或降级为离线只读缓存」两个选项，取了删除（见不足 F） |
| `lib/providers/preference_provider.dart` | 被 `me_provider` 取代 |
| + 两个对应的测试文件（20 个用例） | 随其被测文件一起 |

### 6. 测试

`flutter analyze` 干净，**48 个测试全过**，`flutter build web --release` 构建成功。

计数从 49 变 48：随上述两个文件删掉 20 条；原有 23 条**一条没动**、全过；重写 + 新增 25 条。

新的测试替身 `test/helpers/fake_cooking_api.dart` **不是死数据桩** —— 它按契约真的实现了
偏好过滤、人群命中降序、游标分页。所以断言的是「改偏好 → 推荐真的变了」这条链路，而不是
「界面把我喂的数组原样渲染了」这种同义反复。另加了三处计数断言
（`updatePreferencesCalls` / `recommendCalls` / `receivedCursors`），用来证明「保存后确实
重拉了推荐」且「那次请求确实没带游标」—— 只看画面变没变是看不出接线对错的。

### 7. 顺手修掉的一个真 bug

```dart
options.headers['Authorization'] = 'Bearer $this.token';   // ❌
```

Dart 的字符串插值不支持 `$this.field`：它把 `$this` 当对象插入，后面 `.token` 成了字面量，
实际发出的是 `Bearer Instance of 'ApiClient'.token`，后端会一律判成无效 token ——
而现象是「所有接口都 401」，很容易误判成后端鉴权写错了。是我自己写的测试抓到的。

---

## 二、怎么跑起来看到效果

### 前置一：后端要开 CORS（否则浏览器里全不通）

前端是 Flutter web，App 与 API 不同源（App 在 `localhost:<随机端口>`，API 在
`127.0.0.1:8080`）；且每个请求带 `Authorization`、PUT 还带 `Content-Type: application/json`，
两者都会触发预检。**没有 CORS 时浏览器会在客户端拦掉响应，且报错只提 CORS**，不看后端。

按范围声明，我没有动后端代码。补丁放在
`docs/patches/2026-09-24-cors-for-flutter-web.patch`（361 行，含中间件 + 三处接线 + 三个测试文件），
从仓库根目录一条命令即可应用：

```bash
git apply docs/patches/2026-09-24-cors-for-flutter-web.patch
cd server && go test ./...
```

该补丁经过验证：写完时 `go vet` / `go test` 全绿，并用变异测试确认过「把 CORS 挪到鉴权
之后」会让预检测试变红 —— 中间件顺序是这个补丁唯一的坑（预检请求**不携带** `Authorization`，
排在鉴权之后就会被 401 挡下，真实请求永远发不出去）。

**只本地临时绕一下**（不改后端，但别提交）：

```bash
flutter run -d chrome --web-browser-flag=--disable-web-security
```

### 前置二：数据库凭据

`server/.env` 目前不存在，后端起不来。复制 `server/.env.example` 并填入 MySQL 密码即可。

### 启动

```bash
go env -w GOPROXY=https://goproxy.cn,direct     # 一次性，默认代理会 IPv6 超时
cd server && go run ./cmd/api                   # 自动建表 + 灌种子
flutter run -d chrome                           # 另开终端
```

换测试用户：`--dart-define=API_TOKEN=dev-token-user-2`，或用新增的
`.vscode/launch.json`（三个用户各一个启动项）。

### 该看到什么

- 首页昵称来自服务端（`GET /me`），不再是写死的字符串
- 推荐横向列表是服务端下发的菜谱，**6 张 + 一张「更多」卡片**
- 点「更多」拉到第 7–12 条 —— 游标翻页是真会发生的
- 偏好弹窗的三组选项来自服务端字典
- 选「素食主义」保存 → 列表重拉、荤菜消失
- DevTools 的 Network 面板里，每个请求前面都有一个 OPTIONS 预检

---

## 三、不足之处

### A. 没有端到端真跑过（最重要的一条）

本机 MySQL root 需要密码、`server/.env` 不存在，**后端起不来**。所以：

- HTTP 那一层只用**假 dio adapter** 测过（错误信封解析、请求头注入、查询参数），
  没有真的打通一次真实后端
- 具体风险点：dio → Go 的序列化细节（中文与 emoji 的编码）、真实错误信封的边界情况、
  `Content-Type` 协商

建议接手时第一件事就是按第二节跑一遍，把这条补上。

### B. 依赖后端配合：CORS

见前置一。这是**功能性的硬依赖**，不是可选优化。补丁已备好但未应用。

### C. i18n 是混合状态

新增的「加载失败 / 重试 / 更多」三处文案是**硬编码中文**。依据是 `l10n.yaml` 里已有的
约定：「烹饪/社区/统计三页即将被 dio 迁移重写，现在翻译会返工」。但烹饪页原本部分文案
是走 l10n 的，所以现在是 l10n 与硬编码混在同一个页面里。**英文语言下这三处仍是中文。**
若要补齐，需要给 `app_zh.arb` / `app_en.arb` 加 key 并跑 `flutter gen-l10n`。

### D. 「运行时切换用户」只做了一半

契约承诺「设置页可运行时切换用户，免重启」。后端那半我修好了（`X-Debug-Token` 改为覆盖
`Authorization`），但前端**只做到编译期 `--dart-define` 注入**，设置页里并没有切换器。
换句话说：那个后端能力目前**没有被任何界面消费**。

要真正实现：把 `ApiClient` 的 `debugToken` 从编译期常量改成可变状态（例如从
`settingsProvider` 读），再加一个切换 UI。属于未完成，不是已完成。

### E. 认证生命周期未处理

拿到 `UNAUTHORIZED` 只是把错误显示出来 —— 没有跳登录页、没有刷新令牌、没有自动重试。
生产鉴权方案（手机号/第三方登录）在契约里还是「未决事项」，所以刻意没做，但接入真实登录
时这里是必经之路。

### F. 没有离线能力

`preference_storage` 按契约的两个选项里我选了「删除」，而不是「降级为离线只读缓存」。
代价是断网时偏好直接不可用、只能看到错误页，没有兜底。若要离线体验，需要把该文件按
「只读缓存」重建，并想清楚与服务端冲突时以谁为准。

### G. 分页参数是刻意取小的

`RecommendController.pageSize = 6` 是为了让游标路径在 App 里**真的会走到**（种子库共 12 条，
因此有两页）。真实产品应调大，或者改成虚拟滚动 —— 否则「更多」卡片出现得太频繁。
另外只有「加载更多」，没有下拉刷新、没有无限滚动。

### H. 测试替身有漂移风险

`FakeCookingApi` 复刻了服务端的过滤/排序/分页语义。后端改了行为，它**不会**自动跟着变。
它是为被测到的那几条规则而写的（不是全量复刻），但改动后端时仍需人工对照一遍。

### I. 未接的既有占位（多为后续期次，列出以免误判为遗漏）

- `Recipe.imageUrl` 解析了，但 UI 仍用 emoji 占位，**没有渲染网络图片**（种子数据本来也没配图）
- `image_picker` / `flutter_tts` 已声明依赖但**仍未被使用**（拍照识别与语音是 Phase 2/3）
- 社区页仍是假数据，且 `TabController(length: 3)` 与契约「砍掉同城」的要求（应为 2）不一致 —— Phase 3
- 统计页仍是假数据，顶栏还写死「2026年9月」—— Phase 2
- `data_management_screen.dart:44-50` 有条注释说「契约还没有 DELETE /stats/records 与
  DELETE /posts/{id}」，**这条已过时**：契约 `:504`/`:508` 已把它们定为接口 12 和 13

### J. 没有限流与重试

只有契约要求的 10 秒超时，没有请求重试、没有退避。契约定义了 `RATE_LIMITED` 这个错误码，
但前端没有对应处理。

### K. 本次按要求未纳入的后端改动

CORS 那部分（中间件 + 配置 + 测试）我写过、测过、并用变异测试验证过，按「不动协作者代码」
的要求**已从本分支撤出**，以补丁形式放在 `docs/patches/`。也就是说这个补丁是**已验证但未应用**
的状态，不是半成品。

---

## 四、验证状态一览

| 项 | 状态 |
|---|---|
| `flutter analyze` | 干净 |
| `flutter test` | 48/48 通过 |
| `flutter build web --release` | 构建成功（wasm dry-run 警告来自 `flutter_tts`，既有问题，不影响 JS 构建） |
| `go vet` / `go test`（本分支未改后端，确认未受影响） | 全绿 |
| 与真实后端的端到端联调 | **未做**（见不足 A） |
| CORS 补丁 | 已验证可干净应用，未应用（见不足 B/K） |
