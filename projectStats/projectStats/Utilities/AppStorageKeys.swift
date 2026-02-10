import Foundation

/// Centralized registry for all @AppStorage keys.
/// Prevents typos and makes keys discoverable via autocomplete.
enum AppStorageKeys {
    // MARK: - Achievements
    static let achievementNightOwlCount = "achievement.nightOwlCount"
    static let achievementEarlyBirdCount = "achievement.earlyBirdCount"
    static let achievementLastCommitDate = "achievement.lastCommitDate"

    // MARK: - Cloud Sync
    static let syncEndpoint = "sync.endpoint"
    static let syncApiKey = "sync.apiKey"
    static let syncIncludeChat = "sync.include.chat"
    static let syncIncludeProjects = "sync.include.projects"
    static let syncIncludeUsage = "sync.include.usage"
    static let syncIncludeTime = "sync.include.time"
    static let syncIncludeAchievements = "sync.include.achievements"
    static let syncFrequencyMinutes = "sync.frequencyMinutes"
    static let syncEnabled = "sync.enabled"
    static let syncPrompts = "sync.prompts"
    static let syncDiffs = "sync.diffs"
    static let syncAISessions = "sync.aiSessions"
    static let syncTimeEntries = "sync.timeEntries"
    static let syncAchievements = "sync.achievements"
    static let syncAutomatic = "sync.automatic"
    static let syncIntervalMinutes = "sync.intervalMinutes"

    // MARK: - XP
    static let xpTotalXP = "xp.totalXP"
    static let xpCurrentLevel = "xp.currentLevel"
    static let xpLastDailyBonusDate = "xp.lastDailyBonusDate"
    static let xpCurrentStreak = "xp.currentStreak"
    static let xpLastStreakDate = "xp.lastStreakDate"

    // MARK: - Subscription
    static let subscriptionProCode = "subscription.proCode"
    static let subscriptionIsProActive = "subscription.isProActive"

    // MARK: - VIBE
    static let vibePermissionMode = "vibePermissionMode"

    // MARK: - General Settings
    static let codeDirectoryPath = "codeDirectoryPath"
    static let defaultEditorRaw = "defaultEditorRaw"
    static let defaultTerminalRaw = "defaultTerminalRaw"
    static let refreshInterval = "refreshInterval"
    static let launchAtLogin = "launchAtLogin"
    static let showInDock = "showInDock"
    static let themeRaw = "themeRaw"
    static let accentColorHex = "accentColorHex"
    static let showHiddenFiles = "showHiddenFiles"
    static let homePageLayout = "homePageLayout"
    static let chartTimeRange = "chartTimeRange"
    static let chartDataType = "chartDataType"
    static let customProjectPaths = "customProjectPaths"

    // MARK: - Notifications
    static let notifyClaudeFinished = "notifyClaudeFinished"
    static let playSoundOnClaudeFinished = "playSoundOnClaudeFinished"
    static let notificationSound = "notificationSound"
    static let notifyBuildComplete = "notifyBuildComplete"
    static let notifyServerStart = "notifyServerStart"
    static let notifyContextHigh = "notifyContextHigh"
    static let notifyPlanUsageHigh = "notifyPlanUsageHigh"
    static let notifyGitPushCompleted = "notifyGitPushCompleted"
    static let notifyAchievementUnlocked = "notifyAchievementUnlocked"
    static let pushNotificationsEnabled = "pushNotificationsEnabled"
    static let ntfyTopic = "ntfyTopic"

    // MARK: - Messaging
    static let messagingService = "messaging.service"
    static let messagingTelegramToken = "messaging.telegram.token"
    static let messagingTelegramChat = "messaging.telegram.chat"
    static let messagingSlackWebhook = "messaging.slack.webhook"
    static let messagingDiscordWebhook = "messaging.discord.webhook"
    static let messagingNtfyTopic = "messaging.ntfy.topic"
    static let messagingNotificationsEnabled = "messaging.notifications.enabled"
    static let messagingRemoteEnabled = "messaging.remote.enabled"
    static let messagingRemoteInterval = "messaging.remote.interval"

    // MARK: - AI
    static let aiProvider = "ai.provider"
    static let aiModel = "ai.model"
    static let aiBaseURL = "ai.baseUrl"
    static let aiDefaultModel = "ai.defaultModel"
    static let aiDefaultThinkingLevel = "ai.defaultThinkingLevel"
    static let aiShowModelInToolbar = "ai.showModelInToolbar"

    // MARK: - Tab Visibility
    static let showPromptsTab = "showPromptsTab"
    static let showDiffsTab = "showDiffsTab"
    static let showEnvironmentTab = "showEnvironmentTab"

    // MARK: - Agent Teams
    static let agentTeamsEnabled = "agentTeams.enabled"
    static let swarmWarningDismissed = "swarm.warningDismissed"

    // MARK: - Terminal
    static let terminalClaudeModel = "terminal.claudeModel"
    static let terminalClaudeFlags = "terminal.claudeFlags"
    static let terminalCcyoloModel = "terminal.ccyoloModel"
    static let terminalCodexModel = "terminal.codexModel"
    static let terminalShowClaudeButton = "terminal.showClaudeButton"
    static let terminalShowCcyoloButton = "terminal.showCcyoloButton"
    static let terminalShowCodexButton = "terminal.showCodexButton"

    // MARK: - Claude Usage Widget
    static let ccusageShowCost = "ccusage_showCost"
    static let ccusageShowChart = "ccusage_showChart"
    static let ccusageShowInputTokens = "ccusage_showInputTokens"
    static let ccusageShowOutputTokens = "ccusage_showOutputTokens"
    static let ccusageShowCacheTokens = "ccusage_showCacheTokens"
    static let ccusageShowModelBreakdown = "ccusage_showModelBreakdown"
    static let ccusageDaysToShow = "ccusage_daysToShow"

    // MARK: - TTS / Voice
    static let elevenLabsVoiceId = "elevenLabs_voiceId"
    static let ttsEnabled = "tts_enabled"
    static let ttsProvider = "tts_provider"
    static let voiceAutoTranscribe = "voice_autoTranscribe"

    // MARK: - Focus Mode
    static let focusModeEdgeFXMode = "focusMode.edgeFXMode"

    // MARK: - Workspace Layout
    static let workspaceTerminalWidth = "workspace.terminalWidth"
    static let workspaceExplorerWidth = "workspace.explorerWidth"
    static let workspaceViewerWidth = "workspace.viewerWidth"
    static let workspaceShowTerminal = "workspace.showTerminal"
    static let workspaceShowExplorer = "workspace.showExplorer"
    static let workspaceShowViewer = "workspace.showViewer"

    // MARK: - Divider Styling
    static let dividerGlowOpacity = "dividerGlowOpacity"
    static let dividerGlowRadius = "dividerGlowRadius"
    static let dividerLineThickness = "dividerLineThickness"
    static let dividerBarOpacity = "dividerBarOpacity"
    static let previewDividerGlow = "previewDividerGlow"

    // MARK: - Lockout Bar
    static let lockoutBarSessionColor = "lockoutBar.sessionColor"
    static let lockoutBarWeeklyColor = "lockoutBar.weeklyColor"
    static let lockoutBarWarningColor = "lockoutBar.warningColor"

    // MARK: - Home Data Cards
    static let homeDataShowLinesPerDay = "homeDataShow_linesPerDay"
    static let homeDataShowCommitsPerDay = "homeDataShow_commitsPerDay"
    static let homeDataShowNetLines = "homeDataShow_netLines"
    static let homeDataShowCodeChurnRate = "homeDataShow_codeChurnRate"
    static let homeDataShowLinesPerCommit = "homeDataShow_linesPerCommit"
    static let homeDataShowTotalTimeToday = "homeDataShow_totalTimeToday"
    static let homeDataShowHumanAiTimeSplit = "homeDataShow_humanAiTimeSplit"
    static let homeDataShowAvgSessionLength = "homeDataShow_avgSessionLength"
    static let homeDataShowMostProductiveHour = "homeDataShow_mostProductiveHour"
    static let homeDataShowInputOutputTokens = "homeDataShow_inputOutputTokens"
    static let homeDataShowCacheTokens = "homeDataShow_cacheTokens"
    static let homeDataShowCostUsd = "homeDataShow_costUsd"
    static let homeDataShowModelBreakdown = "homeDataShow_modelBreakdown"
    static let homeDataShowCostPerLine = "homeDataShow_costPerLine"
    static let homeDataShowCostPerCommit = "homeDataShow_costPerCommit"
    static let homeDataShowSessionBlockUsage = "homeDataShow_sessionBlockUsage"
    static let homeDataShowWeeklyUsage = "homeDataShow_weeklyUsage"
    static let homeDataShowUsageRate = "homeDataShow_usageRate"
    static let homeDataShowPredictedTimeToLimit = "homeDataShow_predictedTimeToLimit"
    static let homeDataShowLanguageDistribution = "homeDataShow_languageDistribution"
    static let homeDataShowMostActiveProject = "homeDataShow_mostActiveProject"
    static let homeDataShowProjectHealth = "homeDataShow_projectHealth"
    static let homeDataShowLinesPerDayRolling = "homeDataShow_linesPerDayRolling"
    static let homeDataShowCommitsPerDayRolling = "homeDataShow_commitsPerDayRolling"
    static let homeDataShowVelocityTrend = "homeDataShow_velocityTrend"
    static let homeDataShowWeekOverWeek = "homeDataShow_weekOverWeek"
    static let homeDataShowXpProgress = "homeDataShow_xpProgress"
    static let homeDataShowAchievementProgress = "homeDataShow_achievementProgress"
    static let homeDataShowCurrentStreak = "homeDataShow_currentStreak"
    static let homeDataShowLongestStreak = "homeDataShow_longestStreak"
}
