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

**登录设计极简**：邮箱验证码注册/登录，无密码，无头像，昵称 ≤6 字。后端按邮箱、IP 和全站预算限流。

---

## 二、当前前端状态（你需要对接的）

| 模块 | 现状 |
|------|------|
| Kimi AI 解析 | ✅ 已接入，前端直连 `api.moonshot.cn`，后端**无需处理** |
| 本地数据库 | ✅ Drift (SQLite)，`FlowIntent` + `FocusSession` 两张表 |
| 认证 | 邮箱验证码，已接入阿里云 DirectMail；需配置服务端发信凭证 |
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

### 3.1 认证模块 `/auth`（邮箱验证码，2026-09）

- 无密码。验证邮箱即注册或登录；新用户或尚未设置昵称的用户进入昵称步骤。
- 不再接受 phone、sms_code、device_id 等旧参数，旧版 token 不再有效。
- 邮箱统一校验并转为小写。历史手机号用户和业务记录保留，不自动合并到新邮箱账号。

#### POST `/auth/send-code`

请求：`{"email":"name@qq.com"}`

成功：`{"expires_in":300,"retry_after":60}`

阿里云 DirectMail SingleSendMail 触发邮件；服务端生成随机 6 位数字，Redis 仅存 HMAC 摘要，300 秒过期，不向接口响应或日志输出验证码。

限流为 Redis 原子计数（从首次请求起计算窗口）：

- 同邮箱：1 次/60 秒、5 次/小时、10 次/24 小时。
- 同 IP：5 次/分钟、30 次/小时。
- 全站：20 次/分钟、默认 500 次/24 小时（EMAIL_DAILY_LIMIT）。
- 失败发送仍消耗配额；重发替换旧码，发送失败撤销该码。
- 429 返回 Retry-After；权限、配置、Redis 或发信异常返回 503，绝不使用固定验证码降级。

#### POST `/auth/verify-code`

请求：`{"email":"name@qq.com","code":"邮件中的六位数字"}`

成功示例：

```json
{"token":"jwt","is_new_user":true,"user":{"id":"uuid","email":"name@qq.com","nickname":""}}
```

验证码只能消费一次，最多输错 5 次即作废；校验接口限每 IP 30 次/分钟、全站 300 次/分钟。账号通过唯一邮箱定位，昵称为空时 is_new_user 为 true。

错误：400 EMAIL_CODE_INVALID；429 VERIFY_RATE_LIMITED；503 EMAIL_UNAVAILABLE；请求格式错误为 422。

#### POST `/auth/set-nickname`

需 Bearer token。请求 `{"nickname":"晴山"}`，去除首尾空白、1–6 字，不要求全站唯一。

响应 `{"user":{"id":"uuid","email":"name@qq.com","nickname":"晴山"}}`。

#### POST `/auth/logout`

需 Bearer token。当前 token 加入 Redis 黑名单，返回 204。

#### GET `/auth/me`

需 Bearer token。返回 id、email、nickname、created_at。

错误统一为 `{"detail":{"code":"...","message":"..."}}`，422 为 FastAPI 字段校验格式。

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

1. **无密码设计** — 邮箱验证码，凭证和验证码摘要仅在后端。
2. **时间** — 所有时间字段用 ISO-8601 + 时区（`+08:00`），前端在中国大陆。
3. **Kimi AI** — 前端已直连 `api.moonshot.cn`，后端**完全不需要**代理或转发 AI 请求。
4. **附件图片** — 当前存本地路径，云端同步先忽略，后续单独设计 OSS 方案。
5. **邮件通道** — 阿里云 DirectMail SingleSendMail，RAM 仅授予 dm:SingleSendMail；AccessKey 只存服务器。
6. **防刷** — 详见认证模块的原子限流和错误次数限制。当前不包含人机验证码/WAF，分布式攻击可能耗尽预算，需要结合云端监控和后续风控。
7. **传输安全** — 正式上线前将 API 切为 HTTPS，当前 IP HTTP 地址仅供受控联调。
