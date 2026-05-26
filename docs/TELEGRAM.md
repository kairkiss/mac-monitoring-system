# Telegram Integration

MacMonitor 的 Telegram 集成分为两部分：**Bot 通知** 和 **WebView 小程序**。两者有明确的边界。

## Bot 通知（允许）

MacMonitor 使用你自己的 Telegram Bot 发送以下内容：

- **照片通知**：自动化任务拍摄的照片
- **视频通知**：自动化任务录制的短视频
- **文本消息**：移动侦测告警、系统状态变更

配置方式：在 App Settings 中填写 Bot Token 和 Chat ID。所有消息发往你自己的 Bot/Chat，不会发送给开发者。

## WebView 小程序（允许）

Web 控制台可以作为 Telegram Mini App 在 Telegram 内置浏览器中运行。Telegram WebView 适配包括：

- **主题检测**：读取 `Telegram.WebApp.colorScheme`，自动切换 `telegram-dark` / `telegram-light` CSS 主题
- **主题色适配**：读取 `Telegram.WebApp.themeParams`，将 `bg_color`、`text_color`、`button_color` 映射为 CSS 自定义属性
- **安全区适配**：读取 `Telegram.WebApp.safeAreaInset`，为刘海屏和底部导航栏预留空间
- **视口适配**：`viewport-fit=cover` 配合安全区变量

所有控制操作（拍照、录像、任务管理、存储配置等）都在 Web 页面内完成，与 Telegram 聊天界面无关。

## 明确禁止的功能

以下 Telegram 功能在 MacMonitor 中 **不被使用**，也不会在未来版本中引入：

| 禁止项 | 说明 |
|--------|------|
| `/start`、`/photo`、`/record` 等聊天命令 | 不通过 Telegram 聊天文本控制任何功能 |
| Inline Keyboard | 不在消息下方添加操作按钮 |
| Reply Keyboard | 不在聊天输入区添加快捷按钮 |
| `callback_query` | 不处理 Telegram 按钮回调 |
| `Telegram.WebApp.MainButton` | 不使用 Telegram 原生主按钮执行操作 |
| `Telegram.WebApp.BackButton` | 不使用 Telegram 原生返回按钮 |
| Telegram 聊天文本控制 | 不通过发送聊天消息来触发任何功能 |

**设计原则**：Telegram 是通知渠道和 WebView 容器，不是控制界面。所有用户操作都在 Web 页面内完成。

## 技术实现

### Bot 通知

Telegram 通知由 `TelegramService.swift` 处理，使用原生 URLSession 发送 HTTP 请求到 Telegram Bot API（`https://api.telegram.org/bot<token>/sendMessage` 和 `/sendPhoto`）。不依赖任何第三方 Telegram SDK。

### WebView 适配

Telegram WebView 检测和适配在 `Resources/Web/js/app.js` 中实现：

```javascript
if (window.Telegram?.WebApp) {
    const tg = Telegram.WebApp;
    tg.ready();
    tg.expand();
    document.body.classList.add('telegram-webview');

    // 主题检测
    if (tg.colorScheme === 'dark') document.body.classList.add('telegram-dark');
    else document.body.classList.add('telegram-light');

    // 主题色 CSS 变量
    if (tg.themeParams) { /* 映射到 --tg-bg, --tg-text, --tg-accent */ }

    // 安全区 CSS 变量
    if (tg.safeAreaInset) { /* 映射到 --tg-safe-top, --tg-safe-bottom */ }
}
```

CSS 适配在 `Resources/Web/css/style.css` 的 `.telegram-webview` 相关选择器中。
