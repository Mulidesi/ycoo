package net.ycoo.ycoo_client

import android.app.Application
import androidx.work.Configuration

/// workmanager 0.10.x（androidx.work 2.11）：自定义 WorkManager 初始化
/// （配合 manifest 中移除 androidx.startup 默认初始化器）。后台周期签到使用。
class MainApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()
}
