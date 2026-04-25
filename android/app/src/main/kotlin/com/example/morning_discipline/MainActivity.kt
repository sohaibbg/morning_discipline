package com.example.morning_discipline

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.morning_discipline/usage"
    private val OVERLAY_CHANNEL = "com.example.morning_discipline/overlay"
    private val ALARM_CHANNEL = "com.example.morning_discipline/alarm"
    private val ALARM_PICKER_REQUEST_CODE = 1001
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1002
    private var pendingAlarmResult: MethodChannel.Result? = null
    private var pendingOverlayResult: MethodChannel.Result? = null

    private var overlayView: android.view.View? = null
    private var windowManager: WindowManager? = null
    private var ringtone: android.media.Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    try {
                        val apps = getInstalledApplications()
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get installed apps: ${e.message}", null)
                    }
                }

                "getAppUsage" -> {
                    val packageNames = call.argument<List<String>>("packageNames")
                    val startTime = call.argument<Long>("startTime")
                    val endTime = call.argument<Long>("endTime")

                    if (packageNames == null || startTime == null || endTime == null) {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }

                    if (!hasUsageStatsPermission()) {
                        result.error("NO_PERMISSION", "Usage stats permission not granted", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val usageMap = getAppUsageStats(packageNames, startTime, endTime)
                        result.success(usageMap)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                    }
                }

                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }

                "openUsageStatsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open settings: ${e.message}", null)
                    }
                }

                "getForegroundApp" -> {
                    try {
                        val packageName = getForegroundAppPackage()
                        result.success(packageName)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get foreground app: ${e.message}", null)
                    }
                }

                "startMonitoringService" -> {
                    try {
                        MonitoringService.start(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to start service: ${e.message}", null)
                    }
                }

                "stopMonitoringService" -> {
                    try {
                        MonitoringService.stop(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to stop service: ${e.message}", null)
                    }
                }

                "pickAlarmSound" -> {
                    try {
                        pendingAlarmResult = result
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Sound")
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        }
                        startActivityForResult(intent, ALARM_PICKER_REQUEST_CODE)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open alarm picker: ${e.message}", null)
                        pendingAlarmResult = null
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarm" -> {
                    val uri = call.argument<String>("uri")
                    if (uri != null) {
                        playAlarmSound(uri)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing URI", null)
                    }
                }

                "stopAlarm" -> {
                    stopAlarmSound()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    result.success(canDrawOverlays())
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pendingOverlayResult = result
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }

                "showCountdownOverlay" -> {
                    val remainingSeconds = call.argument<Int>("remainingSeconds")
                    val appName = call.argument<String>("appName")
                    if (remainingSeconds != null && appName != null) {
                        showOverlay(remainingSeconds, appName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }

                "updateCountdown" -> {
                    val remainingSeconds = call.argument<Int>("remainingSeconds")
                    if (remainingSeconds != null) {
                        updateOverlay(remainingSeconds)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }

                "hideCountdownOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == ALARM_PICKER_REQUEST_CODE && pendingAlarmResult != null) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                if (uri != null) {
                    val ringtone = RingtoneManager.getRingtone(this, uri)
                    val title = ringtone.getTitle(this)
                    pendingAlarmResult?.success(mapOf(
                        "uri" to uri.toString(),
                        "title" to title
                    ))
                } else {
                    pendingAlarmResult?.success(null)
                }
            } else {
                pendingAlarmResult?.success(null)
            }
            pendingAlarmResult = null
        }

        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE && pendingOverlayResult != null) {
            pendingOverlayResult?.success(canDrawOverlays())
            pendingOverlayResult = null
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOpsManager.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getAppUsageStats(
        packageNames: List<String>,
        startTime: Long,
        endTime: Long
    ): Map<String, Long> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

        val usageMap = mutableMapOf<String, Long>()
        packageNames.forEach { usageMap[it] = 0L }

        val appStartTimes = mutableMapOf<String, Long>()
        val event = android.app.usage.UsageEvents.Event()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)

            if (event.packageName !in packageNames) continue

            when (event.eventType) {
                android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED -> {
                    // Clamp start time to window start
                    appStartTimes[event.packageName] = maxOf(event.timeStamp, startTime)
                }
                android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
                android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED -> {
                    val startTimestamp = appStartTimes[event.packageName]
                    if (startTimestamp != null) {
                        // Clamp end time to window end
                        val clampedEndTime = minOf(event.timeStamp, endTime)
                        val duration = clampedEndTime - startTimestamp
                        if (duration > 0) {
                            usageMap[event.packageName] = usageMap[event.packageName]!! + duration
                        }
                        appStartTimes.remove(event.packageName)
                    }
                }
            }
        }

        // Handle apps still in foreground at endTime
        appStartTimes.forEach { (packageName, startTimestamp) ->
            val duration = endTime - startTimestamp
            if (duration > 0) {
                usageMap[packageName] = usageMap[packageName]!! + duration
            }
        }

        return usageMap
    }

    private fun getInstalledApplications(): List<Map<String, String>> {
        val packageManager = packageManager
        val apps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { app ->
                // Only include apps that have a launcher intent (user-facing apps)
                packageManager.getLaunchIntentForPackage(app.packageName) != null
            }
            .map { app ->
                mapOf(
                    "appName" to app.loadLabel(packageManager).toString(),
                    "packageName" to app.packageName
                )
            }
            .sortedBy { it["appName"] }
    }

    private fun getForegroundAppPackage(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            time - 1000 * 10, // Last 10 seconds
            time
        )

        if (usageStatsList.isEmpty()) return null

        // Get the most recently used app
        val sortedStats = usageStatsList.sortedByDescending { it.lastTimeUsed }
        return sortedStats.firstOrNull()?.packageName
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun showOverlay(remainingSeconds: Int, appName: String) {
        if (!canDrawOverlays()) return

        hideOverlay() // Remove any existing overlay

        val layoutParams = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 100
        }

        overlayView = LayoutInflater.from(this).inflate(
            android.R.layout.simple_list_item_1,
            null
        ).apply {
            findViewById<TextView>(android.R.id.text1)?.apply {
                text = formatCountdownText(remainingSeconds, appName)
                textSize = 20f
                setTextColor(android.graphics.Color.WHITE)
                setBackgroundColor(android.graphics.Color.parseColor("#CC000000"))
                setPadding(40, 20, 40, 20)
            }
        }

        windowManager?.addView(overlayView, layoutParams)
    }

    private fun updateOverlay(remainingSeconds: Int) {
        overlayView?.findViewById<TextView>(android.R.id.text1)?.apply {
            text = formatCountdownText(remainingSeconds, "")
        }
    }

    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
    }

    private fun formatCountdownText(seconds: Int, appName: String): String {
        val minutes = seconds / 60
        return if (minutes > 0) {
            "${minutes}m left"
        } else {
            "${seconds}s left"
        }
    }

    private fun playAlarmSound(uriString: String) {
        try {
            stopAlarmSound() // Stop any existing alarm

            val uri = if (uriString == "default") {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            } else {
                Uri.parse(uriString)
            }

            ringtone = RingtoneManager.getRingtone(this, uri)
            ringtone?.play()
        } catch (e: Exception) {
            // Fallback to default alarm
            val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ringtone = RingtoneManager.getRingtone(this, defaultUri)
            ringtone?.play()
        }
    }

    private fun stopAlarmSound() {
        ringtone?.stop()
        ringtone = null
    }

    override fun onDestroy() {
        stopAlarmSound()
        hideOverlay()
        super.onDestroy()
    }
}
