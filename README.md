# MacMonitor · Mac监控系统

v2.5.3 — Google Drive Recovery Alignment Hotfix

> [!TIP]
> 如果 Telegram 内置小程序仍显示旧样式，请关闭并重新打开 Telegram 小程序，或清理 Telegram 内置浏览器缓存。

<p align="center">
  <strong>把一台 Mac 变成可远程管理的本地摄像头监控节点。</strong>
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-14.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5-orange?style=for-the-badge&logo=swift&logoColor=white">
  <img alt="Release" src="https://img.shields.io/github/v/release/kairkiss/mac-monitoring-system?style=for-the-badge&label=release">
  <img alt="License" src="https://img.shields.io/github/license/kairkiss/mac-monitoring-system?style=for-the-badge">
</p>

<p align="center">
  <a href="../../releases">下载最新版本</a>
  ·
  <a href="CHANGELOG.md">更新日志</a>
  ·
  <a href="PRIVACY.md">隐私说明</a>
</p>

> **v2.5.3 — Google Drive Recovery Alignment Hotfix**
> Google Drive 连接状态产品化（6 种状态 + 用户引导）、6 个专用 API 端点、Storage Center Drive 详情卡、Uploads 错误描述增强（含 nextAction）、Dashboard 状态感知告警。详见 [CHANGELOG.md](CHANGELOG.md)。

---

## 项目简介

**MacMonitor** 是一个原生 macOS 摄像头监控应用。它可以常驻菜单栏，进行实时预览、拍照、录像、移动侦测、定时任务、Telegram 推送，并提供一个内置 Web 控制台用于远程查看、任务管理、媒体管理、上传队列监控和 Cloudflare Tunnel 远程访问。

它适合这些场景：

- 将闲置 Mac 变成轻量级摄像头节点
- 在局域网或 Cloudflare Tunnel 后远程查看采集状态
- 自动拍照 / 录像并按策略上传到本地目录、挂载目录或 Google Drive
- 用 Telegram 接收关键截图、视频或移动侦测提醒
- 保留完整本地控制，不默认上传数据，不接入统计 SDK

> 请仅在你拥有或已获得授权的设备、空间和场景中使用本项目。

## 功能亮点

| 模块 | 能力 |
| --- | --- |
| 📷 摄像头采集 | 实时预览、拍照、录像、多摄像头选择、摄像头偏好持久化与故障回退 |
| 🗂 媒体库 | 照片 / 视频浏览、删除、缩略图、EXIF、滑动浏览、缩放、幻灯片模式 |
| ⏱ 自动化任务 | Daily、Weekly、Countdown、Interval 四类任务；支持照片 / 视频动作、运行历史、任务级上传策略 |
| 🚨 移动侦测 | 基于帧差的移动侦测、可调灵敏度、冷却时间、自动抓拍、事件短视频 |
| 🤖 Telegram 推送 | 使用你自己的 Bot Token 与 Chat ID 推送照片和视频 |
| 🌐 Web 控制台 | 内置 HTTP 服务，双语界面，角色感知 UI，支持相机、媒体、任务、日志、健康状态、上传队列和设置管理 |
| 🔐 多用户权限 | admin / operator / viewer 三层角色，Web 前端按角色显示/禁用控件，后端 API 按角色校验，带审计日志 |
| ☁️ 存储与归档 | 本地目录、挂载目录、Google Drive；上传队列支持重试、进度、暂停 / 恢复与验证 |
| 🧹 保留策略 | 云端验证后自动清理本地原件，跳过上传中 / 队列中的媒体，可保护收藏和缩略图 |
| 🔭 Cloudflare Tunnel | Quick Tunnel 临时 URL 或 Named Tunnel 固定域名；支持状态检测、配置生成、启动 / 停止 / 重启 |
| 🩺 健康监控 | 摄像头断开、低磁盘、上传失败、存储 Provider 异常等提醒 |
| 📊 报告与延时 | 每日活动报告、延时摄影照片采集与视频合成 |
| 🌏 双语 UI | macOS App 与 Web Dashboard 支持中文 / English 切换 |

> WebDAV 后端与上传带宽限速属于规划中能力，当前 README 不将它们描述为已完整可用功能。

## 截图

> Coming soon. 建议后续把图片放到 `docs/screenshots/`，例如：
>
> - `docs/screenshots/dashboard.png`
> - `docs/screenshots/media-library.png`
> - `docs/screenshots/automation.png`
> - `docs/screenshots/cloudflare.png`

## 系统要求

- macOS 14.0 Sonoma 或更高版本
- 内置或外接摄像头
- Xcode 15+（仅从源码构建时需要）
- 可选：Telegram Bot、Google Drive OAuth 凭据、`cloudflared`

## 安装使用

### 方式一：下载 Release

1. 打开 [Releases](../../releases)
2. 下载最新的 `MacMonitor-v*-macOS.zip`
3. 解压后将 `CameraApp.app` 拖入 Applications
4. 首次启动如遇 Gatekeeper 拦截，请右键 App → **Open / 打开**

> 当前 App 未签名、未 notarize。若你要分发给更多用户，建议配置 Developer ID 签名与公证流程。

### 方式二：从源码构建

```bash
git clone https://github.com/kairkiss/mac-monitoring-system.git
cd mac-monitoring-system
./build.sh
```

构建完成后会输出：

```text
build/release/CameraApp.app
build/release/MacMonitor-v<version>-macOS.zip
```

你也可以直接使用 Xcode / xcodebuild：

```bash
xcodebuild \
  -project CameraApp.xcodeproj \
  -scheme CameraApp \
  -configuration Release \
  build
```

如需签名，`build.sh` 支持通过环境变量开启：

```bash
ENABLE_CODESIGN=true \
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
./build.sh
```

## 快速配置

### 1. 基础权限

首次运行时，按提示授予摄像头权限。若要使用 Web 控制台或远程访问，还需要允许本地网络访问。

### 2. Web 控制台

在 macOS App 的 Settings 中启用 Web Server。默认配置：

```text
Bind Address: 127.0.0.1
Port:         8765
URL:          http://127.0.0.1:8765
```

Web 登录默认会生成 admin 用户密码，请在 App 设置中查看并尽快修改。支持在 macOS 设置页或 Web 设置页修改管理员用户名和密码。

建议保持默认 `127.0.0.1` 绑定，不要直接把端口暴露到公网；需要公网访问时优先使用 Cloudflare Tunnel。

### 3. Telegram 推送

1. 通过 [@BotFather](https://t.me/BotFather) 创建 Bot 并获取 **Bot Token**
2. 获取你的 **Chat ID**（可使用 [@userinfobot](https://t.me/userinfobot)）
3. 在 App Settings 中填写 Bot Token 与 Chat ID
4. 创建自动化任务时勾选 **Send to Telegram**

所有 Telegram 推送都发往你自己的 Bot / Chat，不会发送给开发者。

### 4. 自动化任务

| 类型 | 说明 | 常见用途 |
| --- | --- | --- |
| Daily | 每天固定时间执行 | 每日定点截图 |
| Weekly | 指定星期几执行 | 工作日巡检 |
| Countdown | N 分钟后执行一次 | 临时倒计时抓拍 |
| Interval | 每隔 N 分钟执行，可设置运行窗口 | 长时间间隔采集 / 延时素材 |

任务支持照片或视频动作，并可单独配置是否上传到云端、是否发送 Telegram。

### 5. 存储与上传队列

当前可用后端：

- **Local Folder**：保存到本地自定义目录
- **Mounted Folder**：保存到已挂载的网络盘 / 外置盘目录
- **Google Drive**：OAuth 登录后进行分块上传、远端文件验证与唯一文件名保护

上传队列支持：

- 持久化队列
- 失败重试与指数退避
- 进度显示
- 暂停 / 恢复
- 上传后验证
- Provider 断开时等待重连

### 6. Cloudflare Tunnel 远程访问

MacMonitor 支持两种 Cloudflare Tunnel 模式：

| 模式 | 适合场景 |
| --- | --- |
| Quick Tunnel | 临时公开 URL，适合快速测试 |
| Named Tunnel | 固定域名，适合长期远程访问 |

在 **Settings → Web & Remote Access** 中可以检测 `cloudflared`、生成 / 写入配置、启动、停止、重启 Tunnel，并在异常状态下使用 Force Stop / Reset Status 恢复状态机。

## Web Dashboard 与 API

Web 控制台由 App 内置 HTTP Server 提供，静态资源位于：

```text
CameraApp/Resources/Web/
```

后端 API 按模块拆分：

```text
CameraApp/WebServer/API/
├── APIAuthHandler.swift
├── APIStatusHandler.swift
├── APICameraHandler.swift
├── APIMediaHandler.swift
├── APITaskHandler.swift
├── APILogHandler.swift
├── APIHealthHandler.swift
├── APIUploadHandler.swift
├── APIStorageHandler.swift
└── APIReportHandler.swift
```

典型 API 能力包括：

- 登录、登出、会话校验
- 相机快照、拍照、录像控制
- 媒体列表、缩略图、下载、HTTP Range 大文件读取
- 自动化任务 CRUD
- 活动日志 / 审计日志
- 健康状态与告警
- 上传队列状态、重试、暂停、恢复
- 存储 Provider 诊断、Google Drive 状态、保留策略 dry-run
- Cloudflare Tunnel 状态、启动、停止、重启与配置生成

## 项目结构

```text
mac-monitoring-system/
├── CameraApp.xcodeproj/          # Xcode project
├── CameraApp/
│   ├── CameraApp.swift           # App entry
│   ├── CameraManager.swift       # Camera session / capture core
│   ├── AutomationScheduler.swift # Scheduled tasks and execution history
│   ├── SettingsStore.swift       # App settings persistence
│   ├── WebServer/                # Embedded HTTP server and REST API
│   │   └── API/
│   ├── Storage/                  # Storage providers, Google Drive, Cloudflare Tunnel
│   ├── Upload/                   # Persistent upload queue
│   ├── Features/                 # Retention, event recording, reports, timelapse
│   └── Resources/Web/            # Web dashboard frontend
├── docs/
├── CHANGELOG.md
├── PRIVACY.md
├── LICENSE
└── build.sh
```

## 数据与隐私

- 摄像头权限仅用于本机预览、拍照与录像
- 媒体默认保存在本机 Application Support 目录
- Telegram、Google Drive、Cloudflare 均为可选配置
- Telegram Bot Token、Google Drive Client Secret 等敏感信息尽量存储在本机 Keychain
- 不包含统计分析、遥测或第三方追踪 SDK
- Web 控制台支持登录、会话、角色权限与审计日志

更多细节见 [PRIVACY.md](PRIVACY.md)。

## Roadmap / 可能的下一步

- [ ] 补充 Dashboard、媒体库、自动化、Cloudflare 设置页截图
- [ ] 完善 WebDAV Provider
- [ ] 完成上传带宽限速
- [ ] 增加安装 / 签名 / notarization 文档
- [ ] 增加更多自动化任务模板
- [ ] 为 REST API 补充 OpenAPI 或接口文档

## 版本记录

查看完整历史：[CHANGELOG.md](CHANGELOG.md)

最新版本：**v2.5.1**

## License

[MIT](LICENSE)
