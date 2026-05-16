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
    static var tokenNote: String { lang == .chinese ? "Token 已安全保存在系统 Keychain 中。" : "Token securely stored in system Keychain." }

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

    // MARK: - Export
    static var share: String { lang == .chinese ? "分享" : "Share" }
    static var copyToClipboard: String { lang == .chinese ? "拷贝到剪贴板" : "Copy to Clipboard" }
    static var exportToFile: String { lang == .chinese ? "导出" : "Export to File" }
    static var copied: String { lang == .chinese ? "已拷贝" : "Copied" }
    static var exportSuccess: String { lang == .chinese ? "导出成功" : "Exported successfully" }
    static var exportFailed: String { lang == .chinese ? "导出失败" : "Export failed" }

    // MARK: - Multi-Camera
    static var selectCamera: String { lang == .chinese ? "选择摄像头" : "Select Camera" }
    static var cameraDisconnected: String { lang == .chinese ? "摄像头已断开" : "Camera Disconnected" }
    static var reconnecting: String { lang == .chinese ? "重新连接中..." : "Reconnecting..." }

    // MARK: - Watermark
    static var enableWatermark: String { lang == .chinese ? "启用时间水印" : "Enable Timestamp Watermark" }
    static var watermarkDesc: String { lang == .chinese ? "拍照时在照片上添加时间戳" : "Add timestamp overlay when taking photos" }

    // MARK: - Storage Management
    static var storageUsage: String { lang == .chinese ? "存储占用" : "Storage Usage" }
    static var autoClean: String { lang == .chinese ? "自动清理" : "Auto Clean" }
    static var keepLastDays: String { lang == .chinese ? "保留最近天数" : "Keep Last N Days" }
    static var days: String { lang == .chinese ? "天" : "days" }
    static var cleanNow: String { lang == .chinese ? "立即清理" : "Clean Now" }
    static var cleanedCount: String { lang == .chinese ? "已清理 %d 个文件" : "Cleaned %d files" }
    static var noOldFiles: String { lang == .chinese ? "没有需要清理的旧文件" : "No old files to clean" }
    static var totalPhotos: String { lang == .chinese ? "照片总数" : "Total Photos" }
    static var totalVideos: String { lang == .chinese ? "视频总数" : "Total Videos" }
    static var customStoragePath: String { lang == .chinese ? "自定义存储路径" : "Custom Storage Path" }
    static var chooseDirectory: String { lang == .chinese ? "选择目录" : "Choose Directory" }
    static var resetToDefault: String { lang == .chinese ? "恢复默认" : "Reset to Default" }

    // MARK: - Activity Log
    static var activityLog: String { lang == .chinese ? "活动记录" : "Activity Log" }
    static var clearLogs: String { lang == .chinese ? "清除日志" : "Clear Logs" }
    static var exportLogs: String { lang == .chinese ? "导出日志" : "Export Logs" }

    // MARK: - Motion Detection
    static var motionDetection: String { lang == .chinese ? "画面变化检测" : "Motion Detection" }
    static var enableMotionDetection: String { lang == .chinese ? "启用画面变化检测" : "Enable Motion Detection" }
    static var motionSensitivity: String { lang == .chinese ? "灵敏度" : "Sensitivity" }
    static var motionCooldown: String { lang == .chinese ? "冷却时间" : "Cooldown" }
    static var captureOnMotion: String { lang == .chinese ? "检测到变化时拍照" : "Capture on Motion" }
    static var telegramOnMotion: String { lang == .chinese ? "检测到变化时发送 Telegram" : "Send to Telegram on Motion" }
    static var low: String { lang == .chinese ? "低" : "Low" }
    static var medium: String { lang == .chinese ? "中" : "Medium" }
    static var high: String { lang == .chinese ? "高" : "High" }
    static var seconds: String { lang == .chinese ? "秒" : "seconds" }
    static var motionDetected: String { lang == .chinese ? "检测到画面变化" : "Motion Detected" }

    // MARK: - Health Monitor
    static var healthMonitor: String { lang == .chinese ? "健康监控" : "Health Monitor" }
    static var enableHealthMonitor: String { lang == .chinese ? "启用健康监控" : "Enable Health Monitor" }
    static var notifyCameraDisconnect: String { lang == .chinese ? "摄像头断开时通知" : "Notify on Camera Disconnect" }
    static var notifyLowDisk: String { lang == .chinese ? "磁盘空间不足时通知" : "Notify on Low Disk Space" }
    static var notifyTelegramFailure: String { lang == .chinese ? "Telegram 连续失败时通知" : "Notify on Telegram Failure" }
    static var lowDiskThreshold: String { lang == .chinese ? "低磁盘空间阈值 (MB)" : "Low Disk Threshold (MB)" }

    // MARK: - Notifications
    static var notifications: String { lang == .chinese ? "通知" : "Notifications" }
    static var enableNotifications: String { lang == .chinese ? "启用本地通知" : "Enable Local Notifications" }
    static var notifyOnErrors: String { lang == .chinese ? "出错时通知" : "Notify on Errors" }
    static var notifyOnMotion: String { lang == .chinese ? "画面变化时通知" : "Notify on Motion" }

    // MARK: - Keychain
    static var keychain: String { lang == .chinese ? "Keychain" : "Keychain" }
    static var tokenInKeychain: String { lang == .chinese ? "Bot Token 已存储在 Keychain 中" : "Bot Token stored in Keychain" }
    static var clearToken: String { lang == .chinese ? "清除 Token" : "Clear Token" }
    static var openPrivacyPolicy: String { lang == .chinese ? "查看隐私政策" : "Open Privacy Policy" }

    // MARK: - Automation Recovery
    static var missedTaskRecovery: String { lang == .chinese ? "错过任务恢复" : "Missed Task Recovery" }
    static var recoveryWindow: String { lang == .chinese ? "恢复窗口 (分钟)" : "Recovery Window (minutes)" }
    static var lastRun: String { lang == .chinese ? "上次执行" : "Last Run" }

    // MARK: - Media Index
    static var favorites: String { lang == .chinese ? "收藏" : "Favorites" }
    static var addToFavorites: String { lang == .chinese ? "添加收藏" : "Add to Favorites" }
    static var removeFromFavorites: String { lang == .chinese ? "取消收藏" : "Remove from Favorites" }
    static var source: String { lang == .chinese ? "来源" : "Source" }
    static var manual: String { lang == .chinese ? "手动" : "Manual" }
    static var automation: String { lang == .chinese ? "自动任务" : "Automation" }
    static var motion: String { lang == .chinese ? "画面变化" : "Motion" }
    static var imported: String { lang == .chinese ? "导入" : "Imported" }
    static var telegramStatus: String { lang == .chinese ? "Telegram 状态" : "Telegram Status" }
    static var searchFiles: String { lang == .chinese ? "搜索文件名..." : "Search files..." }

    // MARK: - Privacy & Security
    static var privacySecurity: String { lang == .chinese ? "隐私与安全" : "Privacy & Security" }

    // MARK: - Capture Settings
    static var captureSettings: String { lang == .chinese ? "拍摄设置" : "Capture Settings" }
    static var automationSettings: String { lang == .chinese ? "自动化设置" : "Automation Settings" }
    static var storageSettings: String { lang == .chinese ? "存储设置" : "Storage Settings" }
    static var notificationSettings: String { lang == .chinese ? "通知设置" : "Notification Settings" }

    // MARK: - CaptureError
    static var noVideoFrame: String { lang == .chinese ? "没有视频帧" : "No video frame available" }
    static var imageCreationFailed: String { lang == .chinese ? "图片创建失败" : "Failed to create image" }
    static var jpegEncodingFailed: String { lang == .chinese ? "JPEG 编码失败" : "Failed to encode JPEG" }
    static var diskSpaceInsufficient: String { lang == .chinese ? "磁盘空间不足" : "Disk space insufficient" }
    static var captureFailed: String { lang == .chinese ? "拍照失败" : "Capture failed" }
}
