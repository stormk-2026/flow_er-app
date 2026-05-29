# 流境（Echo Flow）后端接口规格说明

> 本文档面向后端开发者。请通读「产品理解」部分再看接口，否则容易做偏。

---

## 一、产品理解

**流境**是一款面向中国用户的「零摩擦 AI 陪伴」App，不是传统 to-do 工具。

核心哲学：**少即是多，不打扰，不强迫记录**。

三个主 Tab 构成完整闭环：

| Tab | 中文名 | 定位 |
|-----|--------|------|
| 左 | 心笺 | 灵感/念头碎片的展示墙，来自冥想中随手记录 |
| 中 | 流境主页 | 核心：检测用户「入静」状态，触发专注心流 |
| 右 | 沉淀 | 数据概览：专注时长、心流纯度、心笺收录数等 |

**核心交互路径：**
1. 用户打开 App → 中间页感知状态（传感器 + 手势）
2. 三击屏幕 或 扣置手机 → 进入「心流」专注模式（全屏沉浸）
3. 专注中可随手捕捉念头（快记 or 图文心笺）→ 自动落入左侧心笺
4. 退出专注 → 本地记录一条 FocusSession（时长、是否成功）
5. 自然语言输入 → Kimi AI 解析成结构化意图（已接入，**前端直连 Kimi，后端无需转发**）

**登录设计极简**：手机号 + 密码 + 短信验证码注册，无头像，昵称 ≤6 字。注册前先过图形验证码防刷。

---

## 二、当前前端状态（你需要对接的）

| 模块 | 现状 |
|------|------|
| Kimi AI 解析 | ✅ 已接入，前端直连 `api.moonshot.cn`，后端**无需处理** |
| 本地数据库 | ✅ Drift (SQLite)，`FlowIntent` + `FocusSession` 两张表 |
| 认证 | ❌ Mock 实现，需替换为真实后端 |
| 数据同步 | ❌ 纯本地，需后端支持云端备份/多端同步 |
| 推送通知 | ❌ 未实现，`dueAt` 字段已存但还没触发 |

---

## 三、需要后端提供的接口

### 基础约定

```
Base URL: https://your-domain/api/v1
Content-Type: application/json
认证方式: Bearer Token (JWT)
错误格式: { "code": "ERROR_CODE", "message": "..." }
```

---

### 3.1 认证模块 `/auth`

#### GET `/auth/captcha`
获取图形验证码（获取短信验证码前必须先过这一关）

后端生成 4 位随机字母数字，带噪点/扭曲，以 Base64 PNG 返回。同时用 Redis 存 `captcha:{id} → code`，TTL 5 分钟。

**Response**
```json
{
  "captcha_id": "uuid",
  "image": "data:image/png;base64,iVBORw..."
}
```

---

#### POST `/auth/send-code`
发送短信验证码（云片通道）

**前置条件**：必须携带有效的图形验证码，后端验证通过后才调云片，验证后立即删除该 `captcha_id`（一次性）。

**限流（后端强制执行）**：
- 同一手机号：60s 内只能发 1 次，10 分钟内最多 3 次
- 同一 IP：1 小时内最多 10 次

**Request**
```json
{
  "phone": "13800138000",
  "captcha_id": "uuid",
  "captcha_code": "A3k9"
}
```

**Response**
```json
{ "expires_in": 300 }
```

**错误码**
- `CAPTCHA_WRONG` — 图形验证码错误
- `CAPTCHA_EXPIRED` — 图形验证码已过期（重新获取）
- `PHONE_RATE_LIMITED` — 该手机号发送过于频繁
- `IP_RATE_LIMITED` — 该 IP 请求过于频繁
- `PHONE_INVALID` — 手机号格式不合法

---

#### POST `/auth/verify-code`
验证短信验证码，自动判断登录或注册

这是核心接口。后端收到验证码后：
- 该手机号**已注册** → 验证通过直接返回 token，`is_new_user: false`
- 该手机号**未注册** → 创建账号（昵称暂为空），返回 token，`is_new_user: true`

前端收到 `is_new_user: true` 后展示昵称填写步骤，填完后调 `/auth/set-nickname`。

**Request**
```json
{
  "phone": "13800138000",
  "sms_code": "123456"
}
```

**Response**
```json
{
  "token": "jwt_token",
  "is_new_user": true,
  "user": {
    "id": "uuid",
    "phone": "138****8000",
    "nickname": ""
  }
}
```

**错误码**
- `SMS_CODE_EXPIRED` — 验证码已过期
- `SMS_CODE_WRONG` — 验证码错误

---

#### POST `/auth/set-nickname`
新用户完成注册后设置昵称（需携带 token）

**Headers**: `Authorization: Bearer <token>`

**Request**
```json
{ "nickname": "昵称（≤6字）" }
```

**Response**
```json
{
  "user": {
    "id": "uuid",
    "phone": "138****8000",
    "nickname": "晴山"
  }
}
```

**错误码**
- `NICKNAME_TOO_LONG` — 昵称超过6字
- `NICKNAME_TAKEN` — 昵称已被使用（如需唯一性约束）

---

#### POST `/auth/logout`
登出（使 token 失效，如用 Redis 维护黑名单）

**Headers**: `Authorization: Bearer <token>`

**Response**: `204 No Content`

---

#### GET `/auth/me`
获取当前登录用户信息

**Headers**: `Authorization: Bearer <token>`

**Response**
```json
{
  "id": "uuid",
  "phone": "138****8000",
  "nickname": "...",
  "created_at": "ISO-8601"
}
```

---

### 3.2 心笺同步模块 `/intents`

> 本地已有 SQLite 存储，后端负责云端备份与多端同步。
> 同步策略：**以 `updated_at` 为准的 last-write-wins**，前端每次登录后做全量拉取，之后增量推送。

#### GET `/intents`
拉取当前用户的所有心笺（登录后首次同步）

**Headers**: `Authorization: Bearer <token>`

**Query**: `?since=ISO-8601` （可选，增量拉取 `updated_at > since` 的记录）

**Response**
```json
{
  "items": [
    {
      "id": "uuid",
      "local_id": 1,
      "title": "整理作品集",
      "raw_input": "明天下午提醒我整理远程工作作品集",
      "note": "放到云盘里",
      "due_at": "2026-05-25T14:00:00+08:00",
      "priority": "medium",
      "tags": ["工作", "整理"],
      "attachments": [],
      "status": "open",
      "created_at": "ISO-8601",
      "updated_at": "ISO-8601"
    }
  ],
  "total": 42
}
```

---

#### POST `/intents/batch`
批量上传（首次登录、或积压的本地新增）

**Headers**: `Authorization: Bearer <token>`

**Request**
```json
{
  "items": [
    {
      "local_id": 1,
      "title": "...",
      "raw_input": "...",
      "note": null,
      "due_at": null,
      "priority": "medium",
      "tags": [],
      "attachments": [],
      "status": "open",
      "created_at": "ISO-8601",
      "updated_at": "ISO-8601"
    }
  ]
}
```

**Response**
```json
{
  "created": 5,
  "id_map": { "1": "server-uuid-xxx" }
}
```

> `id_map` 用于前端把本地 `local_id` 映射回服务端 UUID，以便后续 PATCH/DELETE。

---

#### PATCH `/intents/:id`
更新单条心笺状态（例如标记完成）

**Request**
```json
{
  "status": "done",
  "updated_at": "ISO-8601"
}
```

**Response**: 返回更新后的完整对象。

---

#### DELETE `/intents/:id`
删除心笺

**Response**: `204 No Content`

---

### 3.3 专注记录同步模块 `/focus-sessions`

> 用于右侧「沉淀」Tab 的数据统计。本地记录专注开始/结束时间、是否成功（持续 ≥ N 秒）。

#### POST `/focus-sessions/batch`
批量上传专注记录

**Request**
```json
{
  "items": [
    {
      "local_id": 1,
      "started_at": "ISO-8601",
      "ended_at": "ISO-8601",
      "duration_seconds": 1800,
      "trigger_type": "triple_tap",
      "is_failed": false,
      "excluded_from_stats": false
    }
  ]
}
```

> `trigger_type` 枚举值：`triple_tap`（三击触发）、`sensor`（扣置手机触发）

**Response**
```json
{ "created": 3 }
```

---

#### GET `/focus-sessions/stats`
获取统计汇总（供右侧 Tab 展示）

**Query**: `?period=all|30d|7d`

**Response**
```json
{
  "total_hours": 12.5,
  "intent_count": 38,
  "flow_purity_percent": 74,
  "session_count": 56,
  "failed_count": 14
}
```

---

### 3.4 推送通知模块 `/push` （后续优先级）

> 心笺里有 `due_at` 字段，需要后端在到期前推送本地通知提醒。

#### POST `/push/token`
上报设备推送 token

**Request**
```json
{
  "platform": "ios | android",
  "token": "APNs or FCM token"
}
```

**Response**: `204 No Content`

---

## 四、数据模型参考

### FlowIntent（心笺）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 服务端主键 |
| local_id | Int | 前端本地 SQLite 自增 id，同步映射用 |
| title | String | AI 提取的简短标题 |
| raw_input | String | 用户原始自然语言输入 |
| note | String? | 补充说明 |
| due_at | DateTime? | 截止时间，用于推送提醒 |
| priority | `low\|medium\|high` | 优先级 |
| tags | String[] | 标签数组 |
| attachments | String[] | 本地图片路径（暂时不需要云端存储，后续扩展） |
| status | `open\|done\|archived` | 状态 |

### FocusSession（专注记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 服务端主键 |
| started_at | DateTime | 专注开始时间 |
| ended_at | DateTime | 专注结束时间 |
| duration_seconds | Int | 持续秒数 |
| trigger_type | String | 触发方式 |
| is_failed | Boolean | 是否为失败专注（持续不足阈值） |
| excluded_from_stats | Boolean | 用户手动排除（时间倒流功能） |

---

## 五、优先级建议

```
P0（MVP 必须）:
  GET  /auth/captcha          ← 已删除，60s限流代替
  POST /auth/send-code
  POST /auth/verify-code      ← 登录/注册合一
  POST /auth/set-nickname     ← 仅新用户调用
  GET  /auth/me

P1（登录后立即需要）:
  GET    /intents
  POST   /intents/batch
  PATCH  /intents/:id
  DELETE /intents/:id
  POST   /focus-sessions/batch
  GET    /focus-sessions/stats

P2（后续迭代）:
  POST /push/token
  忘记密码 / 修改昵称
```

---

## 六、其他注意事项

1. **无密码设计** — 纯手机号 + 短信验证码，无需存储密码。
2. **时间** — 所有时间字段用 ISO-8601 + 时区（`+08:00`），前端在中国大陆。
3. **Kimi AI** — 前端已直连 `api.moonshot.cn`，后端**完全不需要**代理或转发 AI 请求。
4. **附件图片** — 当前存本地路径，云端同步先忽略，后续单独设计 OSS 方案。
5. **短信通道** — 使用云片（yunpian.com），API Key 只存后端环境变量，绝不下发给前端。
6. **防刷** — 同一手机号 60s 内只能发 1 次验证码，同一 IP 1 小时内最多 10 次，后端 Redis 实现。
7. **手机号脱敏** — 所有接口返回的 `phone` 字段格式为 `138****8000`，原始手机号只存数据库。
