import Foundation

struct Strings {
    private static var lang: AppLanguage { LanguageManager.shared.currentLanguage }

    // MARK: - Navigation
    static var cameraTitle: String { lang == .chinese ? "相机" : "Camera" }
    static var libraryTitle: String { lang == .chinese ? "相册" : "Library" }
    static var automationTitle: String { lang == .chinese ? "自动化" : "Automation" }
    static var settingsTitle: String { lang == .chinese ? "设置" : "Settings" }

    // MARK: - Camera Controls
    static var takePhoto: String { lang == .chinese ? "拍照" : "Take Photo" }
    static var startRecording: String { lang == .chinese ? "开始录像" : "Start Recording" }
    static var stopRecording: String { lang == .chinese ? "停止录像" : "Stop Recording" }
    static var requestCameraAccess: String { lang == .chinese ? "请求摄像头权限" : "Request Camera Access" }
    static var openSystemSettings: String { lang == .chinese ? "打开系统设置" : "Open System Settings" }
    static var cameraRunning: String { lang == .chinese ? "摄像头运行中" : "Camera Running" }
    static var noCameraDetected: String { lang == .chinese ? "未检测到摄像头" : "No Camera Detected" }
    static var cameraAccessDenied: String { lang == .chinese ? "摄像头权限被拒绝" : "Camera Access Denied" }
    static var checkingCamera: String { lang == .chinese ? "检查摄像头..." : "Checking Camera..." }
    static var sessionFailed: String { lang == .chinese ? "会话启动失败" : "Session Failed" }
    static var cameraStopped: String { lang == .chinese ? "摄像头已停止" : "Camera Stopped" }
    static var photo: String { lang == .chinese ? "照片" : "Photo" }
    static var video: String { lang == .chinese ? "视频" : "Video" }

    // MARK: - Media Library
    static var photos: String { lang == .chinese ? "照片" : "Photos" }
    static var videos: String { lang == .chinese ? "视频" : "Videos" }
    static var emptyLibrary: String { lang == .chinese ? "还没有照片或视频" : "No photos or videos yet" }
    static var noPhotosYet: String { lang == .chinese ? "还没有照片" : "No photos yet" }
    static var noVideosYet: String { lang == .chinese ? "还没有视频" : "No videos yet" }
    static var delete: String { lang == .chinese ? "删除" : "Delete" }
    static var confirmDelete: String { lang == .chinese ? "确认删除" : "Confirm Delete" }
    static var confirmDeleteMessage: String { lang == .chinese ? "确定要删除这个文件吗？此操作不可撤销。" : "Are you sure you want to delete this file? This cannot be undone." }
    static var revealInFinder: String { lang == .chinese ? "在 Finder 中显示" : "Reveal in Finder" }
    static var saved: String { lang == .chinese ? "已保存" : "Saved" }
    static var cancel: String { lang == .chinese ? "取消" : "Cancel" }
    static var select: String { lang == .chinese ? "选择" : "Select" }
    static var done: String { lang == .chinese ? "完成" : "Done" }
    static var batchDelete: String { lang == .chinese ? "批量删除" : "Batch Delete" }

    // MARK: - Automation
    static var scheduledTasks: String { lang == .chinese ? "定时任务" : "Scheduled Tasks" }
    static var newTask: String { lang == .chinese ? "新建任务" : "New Task" }
    static var editTask: String { lang == .chinese ? "编辑任务" : "Edit Task" }
    static var taskName: String { lang == .chinese ? "任务名称" : "Task Name" }
    static var taskType: String { lang == .chinese ? "任务类型" : "Task Type" }
    static var dailyAt: String { lang == .chinese ? "每天定时" : "Daily At" }
    static var weeklyOn: String { lang == .chinese ? "每周指定日" : "Weekly On" }
    static var countdown: String { lang == .chinese ? "倒计时" : "Countdown" }
    static var interval: String { lang == .chinese ? "间隔拍照" : "Interval" }
    static var enable: String { lang == .chinese ? "启用" : "Enable" }
    static var disable: String { lang == .chinese ? "禁用" : "Disable" }
    static var nextExecution: String { lang == .chinese ? "下次执行" : "Next Execution" }
    static var noTasksYet: String { lang == .chinese ? "还没有定时任务" : "No scheduled tasks yet" }
    static var noTasksDescription: String { lang == .chinese ? "点击上方按钮创建自动拍照任务" : "Tap the button above to create an auto-capture task" }
    static var minutes: String { lang == .chinese ? "分钟" : "Minutes" }
    static var hours: String { lang == .chinese ? "小时" : "Hours" }
    static var captureNow: String { lang == .chinese ? "立即拍照" : "Capture Now" }
    static var automationEnabled: String { lang == .chinese ? "自动化已启用" : "Automation Enabled" }
    static var automationDisabled: String { lang == .chinese ? "自动化已禁用" : "Automation Disabled" }
    static var save: String { lang == .chinese ? "保存" : "Save" }
    static var duration: String { lang == .chinese ? "持续时间" : "Duration" }
    static var every: String { lang == .chinese ? "每隔" : "Every" }
    static var for_: String { lang == .chinese ? "持续" : "For" }
    static var weekdays: [String] {
        lang == .chinese
            ? ["日", "一", "二", "三", "四", "五", "六"]
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }

    // MARK: - Settings
    static var telegramSettings: String { lang == .chinese ? "Telegram 设置" : "Telegram Settings" }
    static var botToken: String { lang == .chinese ? "Bot Token" : "Bot Token" }
    static var chatID: String { lang == .chinese ? "Chat ID" : "Chat ID" }
    static var autoSend: String { lang == .chinese ? "自动发送" : "Auto Send" }
    static var sendScope: String { lang == .chinese ? "发送范围" : "Send Scope" }
    static var testSend: String { lang == .chinese ? "测试发送" : "Test Send" }
    static var testing: String { lang == .chinese ? "发送中..." : "Sending..." }
    static var language: String { lang == .chinese ? "语言" : "Language" }
    static var about: String { lang == .chinese ? "关于" : "About" }
    static var storagePath: String { lang == .chinese ? "存储路径" : "Storage Path" }
    static var tokenNote: String { lang == .chinese ? "Token 保存在本地 UserDefaults 中。生产环境建议迁移到 Keychain。" : "Token stored in local UserDefaults. Consider migrating to Keychain for production." }

    // MARK: - Telegram Per-Task
    static var sendToTelegram: String { lang == .chinese ? "推送到 Telegram" : "Send to Telegram" }
    static var sendToTelegramDesc: String { lang == .chinese ? "任务拍摄的照片将自动发送到 Telegram" : "Photos from this task will be sent to Telegram automatically" }
    static var telegram: String { lang == .chinese ? "Telegram" : "Telegram" }

    // MARK: - Status / Toast
    static var photoSavedToast: String { lang == .chinese ? "照片已保存到相册" : "Photo saved to library" }
    static var videoSavedToast: String { lang == .chinese ? "视频已保存到媒体库" : "Video saved to media library" }
    static var taskCreated: String { lang == .chinese ? "任务已创建" : "Task created" }
    static var taskDeleted: String { lang == .chinese ? "任务已删除" : "Task deleted" }
    static var telegramSent: String { lang == .chinese ? "Telegram 发送成功" : "Sent to Telegram" }
    static var telegramFailed: String { lang == .chinese ? "Telegram 发送失败" : "Telegram send failed" }
    static var telegramNotConfigured: String { lang == .chinese ? "请先配置 Telegram Bot Token 和 Chat ID" : "Please configure Telegram Bot Token and Chat ID first" }
    static var savedTo: String { lang == .chinese ? "已保存到" : "Saved to" }

    // MARK: - Menu Bar
    static var openWindow: String { lang == .chinese ? "打开主窗口" : "Open Window" }
    static var toggleAutomation: String { lang == .chinese ? "自动任务" : "Automation" }
    static var toggleTelegram: String { lang == .chinese ? "Telegram 推送" : "Telegram Push" }
    static var quickPhoto: String { lang == .chinese ? "快速拍照" : "Quick Photo" }
    static var openLibrary: String { lang == .chinese ? "打开相册" : "Open Library" }
    static var quit: String { lang == .chinese ? "退出" : "Quit" }
    static var menuBarTitle: String { lang == .chinese ? "Mac监控系统" : "Mac Monitor" }
}
