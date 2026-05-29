# Flow_er

Flow_er 是一款围绕「专注、心笺、沉淀」构建的 Flutter 应用。它以轻量交互进入心流状态，在专注过程中快速记录念头，并通过后端统计与画像能力，把日常专注和心笺逐步沉淀成可回看的个人状态图景。

## 关键功能

- 手机号验证码登录，支持 JWT 会话持久化。
- 三击屏幕或扣置手机进入心流状态。
- 心流中下滑记录心笺，支持快捷想法和展笺两种模式。
- 心笺本地优先保存，并同步到后端做分类打标。
- 心笺支持编辑、删除和多样化原生卡片展示。
- 心笺分类覆盖：巧思、体悟、心绪、纪事、摘录。
- 专注会话结束后自动记录时长、触发方式、是否失败，并上传后端。
- 心流顶部文案每 5 分钟从后端获取一次，用于生成低打扰的专注提示。
- 右侧沉淀页展示总时长、心笺收录、心流纯度、觉察指数、心智质地。
- 统计页支持全部、近 30 天、近 7 天三个周期切换。
- 统计数据在心笺或专注记录变化后自动失效，下次查看时刷新。

## 技术栈

- Flutter
- Riverpod
- Drift / SQLite
- Dio
- SharedPreferences
- sensors_plus
- image_picker
- google_fonts
- flutter_staggered_grid_view

## 目录结构

```text
lib/
  core/                 基础主题、专注常量、文案工具
  features/
    analytics/          右侧沉淀统计页
    auth/               登录、验证码、昵称设置
    home/               早期调试页
    inspiration/        心笺列表、卡片模型和样式库
    settings/           设置页、时间回溯入口
    shell/              主壳、顶部栏、底部一级导航
    splash/             启动页
    state/              心流状态页、心笺记录浮层
  models/               Drift 数据库与业务模型
  providers/            Riverpod Provider 和控制器
  repositories/         本地数据读写封装
  services/
    analytics/          统计页接口
    api/                Dio API 客户端
    focus/              心流文案接口
    sensors/            传感器专注状态
    sync/               心笺与专注会话同步
```

## 后端接口

当前前端已接入以下接口：

- `POST /api/v1/auth/send-code`
- `POST /api/v1/auth/verify-code`
- `POST /api/v1/auth/set-nickname`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/logout`
- `GET /api/v1/intents`
- `POST /api/v1/intents/batch`
- `PATCH /api/v1/intents/{id}`
- `DELETE /api/v1/intents/{id}`
- `POST /api/v1/focus-sessions/batch`
- `GET /api/v1/focus-sessions/stats?period=all|30d|7d`
- `GET /api/v1/focus-sessions/portrait?period=all|30d|7d`
- `POST /api/v1/focus/moment`

API 基础地址位于：

```text
lib/services/api/api_client.dart
```

## 快速开始

安装依赖：

```sh
flutter pub get
```

运行应用：

```sh
flutter run
```

静态检查：

```sh
flutter analyze
```

运行测试：

```sh
flutter test
```

数据库模型变更后重新生成 Drift 代码：

```sh
flutter pub run build_runner build --delete-conflicting-outputs
```

## 数据同步说明

- 心笺先写入本地 SQLite，再同步到后端。
- 心笺同步成功后回写服务端 ID，并拉取后端打标结果。
- 专注会话结束后先写入本地，再通过 batch 接口上传。
- 心笺和专注会话上传失败时会保留本地 pending 数据，后续登录或启动时补传。
- 统计页数据来自后端，心笺或专注记录变化后会让统计缓存失效。

## 待完善事项

- 图片附件上传与远端 URL 同步。
- 心笺增量同步 `since / last_synced_at`。
- 时间回溯状态同步到后端。
- 推送 token 注册。
