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

    // MARK: - Recording Enhancement
    static var recordingElapsed: String { lang == .chinese ? "录像时长" : "Recording Time" }
    static var segmentDuration: String { lang == .chinese ? "自动分段时长 (分钟)" : "Auto-Segment Duration (min)" }
    static var segmentDurationDesc: String { lang == .chinese ? "录像超过此时长后自动分段保存" : "Auto-split recording into segments of this duration" }
    static var enableAudioRecording: String { lang == .chinese ? "录制音频" : "Record Audio" }
    static var audioNotAvailable: String { lang == .chinese ? "未检测到音频设备" : "No audio device available" }
    static var recordingSegment: String { lang == .chinese ? "录像分段" : "Recording Segment" }

    // MARK: - Preview Enhancement
    static var previousItem: String { lang == .chinese ? "上一个" : "Previous" }
    static var nextItem: String { lang == .chinese ? "下一个" : "Next" }
    static var slideshow: String { lang == .chinese ? "幻灯片" : "Slideshow" }
    static var slideshowSpeed: String { lang == .chinese ? "播放速度 (秒)" : "Play Speed (sec)" }
    static var exifInfo: String { lang == .chinese ? "照片信息" : "Photo Info" }
    static var cameraMake: String { lang == .chinese ? "相机品牌" : "Camera Make" }
    static var cameraModel: String { lang == .chinese ? "相机型号" : "Camera Model" }
    static var aperture: String { lang == .chinese ? "光圈" : "Aperture" }
    static var iso: String { lang == .chinese ? "ISO" : "ISO" }
    static var shutterSpeed: String { lang == .chinese ? "快门速度" : "Shutter Speed" }
    static var focalLength: String { lang == .chinese ? "焦距" : "Focal Length" }
    static var gpsLocation: String { lang == .chinese ? "GPS 位置" : "GPS Location" }
    static var imageWidth: String { lang == .chinese ? "宽度" : "Width" }
    static var imageHeight: String { lang == .chinese ? "高度" : "Height" }
    static var fileSizeLabel: String { lang == .chinese ? "文件大小" : "File Size" }
    static var noExifData: String { lang == .chinese ? "无 EXIF 数据" : "No EXIF data available" }
    static var zoomIn: String { lang == .chinese ? "放大" : "Zoom In" }
    static var zoomOut: String { lang == .chinese ? "缩小" : "Zoom Out" }
    static var resetZoom: String { lang == .chinese ? "重置缩放" : "Reset Zoom" }

    // MARK: - Automation Visualization
    static var timeline: String { lang == .chinese ? "时间线" : "Timeline" }
    static var executionHistory: String { lang == .chinese ? "执行记录" : "Execution History" }
    static var taskStatistics: String { lang == .chinese ? "任务统计" : "Task Statistics" }
    static var todayCaptures: String { lang == .chinese ? "今日拍摄" : "Today's Captures" }
    static var todayTelegramSends: String { lang == .chinese ? "今日推送" : "Today's Telegram Sends" }
    static var totalExecutions: String { lang == .chinese ? "总执行次数" : "Total Executions" }
    static var successRate: String { lang == .chinese ? "成功率" : "Success Rate" }
    static var lastExecution: String { lang == .chinese ? "上次执行" : "Last Execution" }
    static var succeeded: String { lang == .chinese ? "成功" : "Succeeded" }
    static var failed: String { lang == .chinese ? "失败" : "Failed" }
    static var noHistoryYet: String { lang == .chinese ? "暂无执行记录" : "No execution history yet" }
    static var history: String { lang == .chinese ? "历史" : "History" }
    static var statistics: String { lang == .chinese ? "统计" : "Statistics" }

    // MARK: - Camera Fallback
    static var usingFallbackCamera: String { lang == .chinese ? "使用备用摄像头" : "Using Fallback Camera" }
    static var waitingForPreferredCamera: String { lang == .chinese ? "等待首选摄像头" : "Waiting for Preferred Camera" }
    static var preferredCameraRestored: String { lang == .chinese ? "首选摄像头已恢复" : "Preferred Camera Restored" }
    static var preferredCameraUnavailable: String { lang == .chinese ? "首选摄像头不可用" : "Preferred Camera Unavailable" }
    static var fallbackCameraActivated: String { lang == .chinese ? "已切换到备用摄像头" : "Fallback Camera Activated" }

    // MARK: - Web Server
    static var webServer: String { lang == .chinese ? "Web 服务器" : "Web Server" }
    static var enableWebServer: String { lang == .chinese ? "启用 Web 服务器" : "Enable Web Server" }
    static var webServerPort: String { lang == .chinese ? "端口" : "Port" }
    static var webServerAddress: String { lang == .chinese ? "监听地址" : "Listen Address" }
    static var webServerRunning: String { lang == .chinese ? "运行中" : "Running" }
    static var webServerStopped: String { lang == .chinese ? "已停止" : "Stopped" }
    static var webDashboardURL: String { lang == .chinese ? "仪表盘地址" : "Dashboard URL" }
    static var openDashboard: String { lang == .chinese ? "打开仪表盘" : "Open Dashboard" }
    static var localAccessToken: String { lang == .chinese ? "访问令牌" : "Access Token" }
    static var regenerateToken: String { lang == .chinese ? "重新生成令牌" : "Regenerate Token" }

    // MARK: - General
    static var none: String { lang == .chinese ? "无" : "None" }

    // MARK: - Storage Providers
    static var storageProviders: String { lang == .chinese ? "存储后端" : "Storage Providers" }
    static var localFolder: String { lang == .chinese ? "本地文件夹" : "Local Folder" }
    static var mountedFolder: String { lang == .chinese ? "挂载文件夹" : "Mounted Folder" }
    static var googleDrive: String { lang == .chinese ? "Google Drive" : "Google Drive" }
    static var webdav: String { lang == .chinese ? "WebDAV" : "WebDAV" }
    static var providerNotConfigured: String { lang == .chinese ? "未配置" : "Not Configured" }
    static var providerConnected: String { lang == .chinese ? "已连接" : "Connected" }
    static var providerDisconnected: String { lang == .chinese ? "未连接" : "Disconnected" }
    static var testConnection: String { lang == .chinese ? "测试连接" : "Test Connection" }
    static var defaultProvider: String { lang == .chinese ? "默认存储后端" : "Default Provider" }

    // MARK: - Upload Queue
    static var uploadQueue: String { lang == .chinese ? "上传队列" : "Upload Queue" }
    static var uploadPending: String { lang == .chinese ? "等待上传" : "Pending" }
    static var uploadInProgress: String { lang == .chinese ? "上传中" : "Uploading" }
    static var uploadCompleted: String { lang == .chinese ? "上传完成" : "Completed" }
    static var uploadFailed: String { lang == .chinese ? "上传失败" : "Failed" }
    static var uploadRetrying: String { lang == .chinese ? "重试中" : "Retrying" }
    static var retryUpload: String { lang == .chinese ? "重试上传" : "Retry" }
    static var cancelUpload: String { lang == .chinese ? "取消上传" : "Cancel" }
    static var autoUploadPhotos: String { lang == .chinese ? "自动上传照片" : "Auto Upload Photos" }
    static var autoUploadVideos: String { lang == .chinese ? "自动上传视频" : "Auto Upload Videos" }
    static var maxConcurrentUploads: String { lang == .chinese ? "最大并发上传数" : "Max Concurrent Uploads" }
    static var bandwidthLimit: String { lang == .chinese ? "带宽限制 (KB/s)" : "Bandwidth Limit (KB/s)" }
    static var bandwidthUnlimited: String { lang == .chinese ? "无限制" : "Unlimited" }

    // MARK: - Retention
    static var retentionPolicy: String { lang == .chinese ? "自动清理策略" : "Retention Policy" }
    static var deleteLocalAfterUpload: String { lang == .chinese ? "上传验证后删除本地原文件" : "Delete local original after verified upload" }
    static var keepLocalDays: String { lang == .chinese ? "本地保留天数" : "Keep Local Days" }
    static var keepThumbnails: String { lang == .chinese ? "保留缩略图" : "Keep Thumbnails" }
    static var protectFavorites: String { lang == .chinese ? "保护收藏文件" : "Protect Favorites" }
    static var gracePeriodHours: String { lang == .chinese ? "宽限期 (小时)" : "Grace Period (hours)" }

    // MARK: - Event Recording
    static var eventRecording: String { lang == .chinese ? "事件录像" : "Event Recording" }
    static var enableEventRecording: String { lang == .chinese ? "启用事件录像" : "Enable Event Recording" }
    static var eventClipDuration: String { lang == .chinese ? "片段时长 (秒)" : "Clip Duration (seconds)" }
    static var uploadEventClips: String { lang == .chinese ? "自动上传事件片段" : "Auto Upload Event Clips" }

    // MARK: - Daily Report
    static var dailyReport: String { lang == .chinese ? "每日报告" : "Daily Report" }
    static var enableDailyReport: String { lang == .chinese ? "启用每日报告" : "Enable Daily Report" }
    static var generateReport: String { lang == .chinese ? "生成报告" : "Generate Report" }
    static var reportTime: String { lang == .chinese ? "报告生成时间" : "Report Time" }

    // MARK: - Timelapse
    static var timelapse: String { lang == .chinese ? "延时摄影" : "Timelapse" }
    static var enableTimelapse: String { lang == .chinese ? "启用延时摄影" : "Enable Timelapse" }
    static var captureInterval: String { lang == .chinese ? "拍摄间隔 (秒)" : "Capture Interval (sec)" }
    static var outputFPS: String { lang == .chinese ? "输出帧率" : "Output FPS" }
    static var autoUploadTimelapse: String { lang == .chinese ? "自动上传延时视频" : "Auto Upload Timelapse" }

    // MARK: - Web Users
    static var webUsers: String { lang == .chinese ? "Web 用户管理" : "Web Users" }
    static var adminRole: String { lang == .chinese ? "管理员" : "Admin" }
    static var operatorRole: String { lang == .chinese ? "操作员" : "Operator" }
    static var viewerRole: String { lang == .chinese ? "查看者" : "Viewer" }
    static var addUser: String { lang == .chinese ? "添加用户" : "Add User" }
    static var requireLogin: String { lang == .chinese ? "需要登录" : "Require Login" }

    // MARK: - Audit Log
    static var auditLog: String { lang == .chinese ? "审计日志" : "Audit Log" }

    // MARK: - Cloudflare
    static var cloudflareTunnel: String { lang == .chinese ? "Cloudflare Tunnel" : "Cloudflare Tunnel" }
    static var cloudflareGuide: String { lang == .chinese ? "远程访问配置指南" : "Remote Access Setup Guide" }

    // MARK: - Google Drive
    static var googleDriveSignIn: String { lang == .chinese ? "登录 Google Drive" : "Sign In to Google Drive" }
    static var googleDriveReconnect: String { lang == .chinese ? "重新连接 Google Drive" : "Reconnect Google Drive" }
    static var googleDriveSignOut: String { lang == .chinese ? "退出 Google Drive" : "Sign Out" }
    static var googleDriveAuthenticated: String { lang == .chinese ? "已登录" : "Authenticated" }
    static var googleDriveNotAuthenticated: String { lang == .chinese ? "未登录" : "Not Authenticated" }
    static var googleDriveNeedsReconnect: String { lang == .chinese ? "需要重新连接" : "Needs Reconnect" }
    static var googleDriveClientID: String { lang == .chinese ? "Google API Client ID" : "Google API Client ID" }
    static var googleDriveClientSecret: String { lang == .chinese ? "Google API Client Secret" : "Google API Client Secret" }
    static var googleDriveRootFolderName: String { lang == .chinese ? "根文件夹名称" : "Root Folder Name" }
    static var googleDriveRootFolderNameDesc: String { lang == .chinese ? "Google Drive 中的文件夹名称，如 MacMonitor" : "Folder name in Google Drive, e.g. MacMonitor" }
    static var googleDriveRootFolder: String { lang == .chinese ? "根文件夹 ID" : "Root Folder ID" }
    static var googleDriveRootFolderDesc: String { lang == .chinese ? "留空使用 My Drive 根目录" : "Leave empty to use My Drive root" }
    static var googleDriveAccount: String { lang == .chinese ? "Google 账户" : "Google Account" }
    static var googleDriveFolderStructure: String { lang == .chinese ? "文件夹结构" : "Folder Structure" }
    static var googleDriveFolderStructureDesc: String { lang == .chinese ? "自动创建 根文件夹/分类/ 目录" : "Auto-creates RootFolder/category/ directories" }
    static var googleDriveSetupDesc: String { lang == .chinese ? "在 Google Cloud Console 创建 OAuth 2.0 凭据（桌面应用类型），然后在此输入 Client ID 和 Secret" : "Create OAuth 2.0 credentials (Desktop app type) in Google Cloud Console, then enter Client ID and Secret here" }
    static var googleDriveRedirectNote: String { lang == .chinese ? "回调地址: http://127.0.0.1（需在 Google Cloud Console 中添加为已授权的重定向 URI）" : "Callback URL: http://127.0.0.1 (must be added as authorized redirect URI in Google Cloud Console)" }
    static var googleDriveResumable: String { lang == .chinese ? "支持断点续传（8MB 分块）" : "Resumable upload (8MB chunks)" }
    static var googleDriveCredentialsRequired: String { lang == .chinese ? "请先输入 Google API Client ID 和 Secret" : "Please enter Google API Client ID and Secret first" }
    static var googleDriveNoOverwrite: String { lang == .chinese ? "不覆盖远端文件" : "No Remote Overwrite" }
    static var googleDriveNoOverwriteDesc: String { lang == .chinese ? "同名文件自动生成新文件名，不会覆盖已有文件" : "Auto-generates unique filenames — never overwrites existing remote files" }
    static var cloudflareSetupWizard: String { lang == .chinese ? "Cloudflare 配置向导" : "Cloudflare Setup Wizard" }
    static var cloudflareStep1: String { lang == .chinese ? "步骤 1: 安装 cloudflared" : "Step 1: Install cloudflared" }
    static var cloudflareStep2: String { lang == .chinese ? "步骤 2: 登录 Cloudflare" : "Step 2: Login to Cloudflare" }
    static var cloudflareStep3: String { lang == .chinese ? "步骤 3: 创建 Tunnel" : "Step 3: Create Tunnel" }
    static var cloudflareStep4: String { lang == .chinese ? "步骤 4: 配置 DNS" : "Step 4: Configure DNS" }
    static var cloudflareStep5: String { lang == .chinese ? "步骤 5: 启动 Tunnel" : "Step 5: Start Tunnel" }
    static var copyCommand: String { lang == .chinese ? "复制命令" : "Copy Command" }
    static var copiedToClipboard: String { lang == .chinese ? "已复制到剪贴板" : "Copied to clipboard" }
    static var cloudflareDoubleProtection: String { lang == .chinese ? "双重保护：Cloudflare Access + 应用登录" : "Double protection: Cloudflare Access + App Login" }
    static var remoteAccess: String { lang == .chinese ? "远程访问" : "Remote Access" }
    static var remoteAccessDesc: String { lang == .chinese ? "通过 Cloudflare Tunnel 从外网安全访问您的监控系统" : "Securely access your monitoring system from the internet via Cloudflare Tunnel" }
    static var doNotExposePort: String { lang == .chinese ? "不要将端口直接暴露到公网" : "Do not expose port directly to the internet" }
    static var webServerLocalURL: String { lang == .chinese ? "本地访问地址" : "Local Access URL" }

    // MARK: - v2.3.3: Diagnostics
    static var storageDiagnostics: String { lang == .chinese ? "存储诊断" : "Storage Diagnostics" }
    static var diagnosticsReport: String { lang == .chinese ? "诊断报告" : "Diagnostics Report" }
    static var connectionTest: String { lang == .chinese ? "连接测试" : "Connection Test" }
    static var uploadVerification: String { lang == .chinese ? "上传验证" : "Upload Verification" }
    static var providerStatus: String { lang == .chinese ? "提供者状态" : "Provider Status" }
    static var lastSuccessfulUpload: String { lang == .chinese ? "上次成功上传" : "Last Successful Upload" }
    static var cloudflaredDetected: String { lang == .chinese ? "cloudflared 已检测到" : "cloudflared Detected" }
    static var cloudflaredNotDetected: String { lang == .chinese ? "未检测到 cloudflared" : "cloudflared Not Detected" }

    // MARK: - v2.3.3: Error Classification
    static var errorAuthExpired: String { lang == .chinese ? "认证已过期，请重新登录" : "Authentication expired. Please sign in again." }
    static var errorQuotaExceeded: String { lang == .chinese ? "存储空间已满" : "Storage quota exceeded" }
    static var errorRateLimited: String { lang == .chinese ? "请求过于频繁，稍后重试" : "Rate limited. Will retry later." }
    static var errorNetworkUnavailable: String { lang == .chinese ? "网络不可用" : "Network unavailable" }
    static var errorPermissionDenied: String { lang == .chinese ? "权限不足" : "Permission denied" }

    // MARK: - v2.3.3: Upload Status
    static var uploadWaitingForProvider: String { lang == .chinese ? "等待存储连接" : "Waiting for Provider" }
    static var errorClass: String { lang == .chinese ? "错误类型" : "Error Type" }

    // MARK: - v2.3.3: Media Badges
    static var cloudBadge: String { lang == .chinese ? "云端" : "Cloud" }
    static var verifiedBadge: String { lang == .chinese ? "已验证" : "Verified" }
    static var archivedBadge: String { lang == .chinese ? "已归档" : "Archived" }
    static var openInGoogleDrive: String { lang == .chinese ? "在 Google Drive 中打开" : "Open in Google Drive" }

    // MARK: - v2.3.3: Retention
    static var dryRunPreview: String { lang == .chinese ? "清理预览" : "Dry Run Preview" }
    static var willDeleteCount: String { lang == .chinese ? "将删除 %d 个本地文件" : "Will delete %d local file(s)" }
    static var retentionSkippedProvider: String { lang == .chinese ? "跳过：存储未连接" : "Skipped: provider not connected" }
    static var runDryRun: String { lang == .chinese ? "预览清理" : "Preview Cleanup" }
    static var quotaInfo: String { lang == .chinese ? "存储配额" : "Storage Quota" }
    static var rootFolderStatus: String { lang == .chinese ? "根目录状态" : "Root Folder Status" }
    static var skipped: String { lang == .chinese ? "跳过" : "skipped" }
    static var verifiedCount: String { lang == .chinese ? "已验证" : "verified" }
    static var failedCount: String { lang == .chinese ? "失败" : "failed" }

    // MARK: - v2.4.0: Upload Policy
    static var uploadToCloud: String { lang == .chinese ? "上传到云端" : "Upload to Cloud" }
    static var uploadToCloudDesc: String { lang == .chinese ? "任务拍摄完成后自动上传到 Google Drive" : "Auto-upload to Google Drive after task capture" }
    static var autoUploadMotionCaptures: String { lang == .chinese ? "自动上传运动检测照片" : "Auto-upload Motion Captures" }
    static var autoUploadMotionCapturesDesc: String { lang == .chinese ? "运动检测触发的照片自动上传（默认关闭）" : "Auto-upload photos triggered by motion detection (default off)" }
    static var localOnly: String { lang == .chinese ? "仅本地" : "Local Only" }

    // MARK: - v2.4.0: OAuth Errors
    static var stateMismatch: String { lang == .chinese ? "安全验证失败（state 不匹配）" : "Security verification failed (state mismatch)" }
    static var accessDenied: String { lang == .chinese ? "访问被拒绝" : "Access denied" }
    static var redirectURIMismatch: String { lang == .chinese ? "重定向 URI 不匹配" : "Redirect URI mismatch" }
    static var invalidClient: String { lang == .chinese ? "无效的客户端" : "Invalid client" }
    static var invalidScope: String { lang == .chinese ? "无效的权限范围" : "Invalid scope" }

    // MARK: - v2.4.0: Cloudflare Tunnel
    static var cloudflareTunnelManage: String { lang == .chinese ? "Cloudflare Tunnel 管理" : "Cloudflare Tunnel Management" }
    static var cloudflareStart: String { lang == .chinese ? "启动 Tunnel" : "Start Tunnel" }
    static var cloudflareStop: String { lang == .chinese ? "停止 Tunnel" : "Stop Tunnel" }
    static var cloudflareStatus: String { lang == .chinese ? "Tunnel 状态" : "Tunnel Status" }
    static var cloudflareRunning: String { lang == .chinese ? "运行中" : "Running" }
    static var cloudflareStopped: String { lang == .chinese ? "已停止" : "Stopped" }
    static var cloudflareStarting: String { lang == .chinese ? "启动中..." : "Starting..." }
    static var cloudflareError: String { lang == .chinese ? "错误" : "Error" }
    static var cloudflareNotConfigured: String { lang == .chinese ? "未配置 Tunnel" : "Tunnel not configured" }

    // MARK: - v2.4.0: Settings Sections
    static var overviewSection: String { lang == .chinese ? "概览" : "Overview" }
    static var cameraSection: String { lang == .chinese ? "摄像头" : "Camera" }
    static var automationSection: String { lang == .chinese ? "自动化" : "Automation" }
    static var storageCloudSection: String { lang == .chinese ? "存储与云端" : "Storage & Cloud" }
    static var webRemoteSection: String { lang == .chinese ? "Web 与远程" : "Web & Remote" }
    static var notificationsSection: String { lang == .chinese ? "通知" : "Notifications" }
    static var healthLogsSection: String { lang == .chinese ? "健康与日志" : "Health & Logs" }
    static var advancedSection: String { lang == .chinese ? "高级" : "Advanced" }
    static var lastCapture: String { lang == .chinese ? "最后拍摄" : "Last Capture" }
    static var lastUpload: String { lang == .chinese ? "最后上传" : "Last Upload" }
    static var googleDriveStatus: String { lang == .chinese ? "Google Drive 状态" : "Google Drive Status" }

    // MARK: - v2.4.1: Task Action Type
    static var actionType: String { lang == .chinese ? "动作类型" : "Action Type" }
    static var videoDuration: String { lang == .chinese ? "录像时长 (秒)" : "Video Duration (sec)" }
    static var photoAction: String { lang == .chinese ? "拍照" : "Photo" }
    static var videoAction: String { lang == .chinese ? "录像" : "Video" }

    // MARK: - v2.4.1: Cloudflare Tunnel
    static var quickTunnel: String { lang == .chinese ? "快速 Tunnel" : "Quick Tunnel" }
    static var namedTunnel: String { lang == .chinese ? "命名 Tunnel" : "Named Tunnel" }
    static var tunnelMode: String { lang == .chinese ? "Tunnel 模式" : "Tunnel Mode" }
    static var quickTunnelDesc: String { lang == .chinese ? "临时 URL，重启后变化" : "Temporary URL, changes on restart" }
    static var namedTunnelDesc: String { lang == .chinese ? "固定域名，需要 Cloudflare 账户" : "Persistent domain, requires Cloudflare account" }
    static var tunnelURL: String { lang == .chinese ? "Tunnel URL" : "Tunnel URL" }
    static var tunnelDiagnostics: String { lang == .chinese ? "Tunnel 诊断" : "Tunnel Diagnostics" }
    static var cloudflaredVersion: String { lang == .chinese ? "cloudflared 版本" : "cloudflared Version" }

    // MARK: - v2.4.1: Admin & Audit
    static var adminOnly: String { lang == .chinese ? "仅管理员" : "Admin Only" }
    static var adminOnlyAction: String { lang == .chinese ? "此操作需要管理员权限" : "This action requires admin privileges" }
    static var auditLogEntry: String { lang == .chinese ? "审计记录" : "Audit Entry" }
}
