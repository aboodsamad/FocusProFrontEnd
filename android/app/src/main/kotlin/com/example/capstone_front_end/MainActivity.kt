package com.example.capstone_front_end

import android.app.AppOpsManager
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.app.usage.UsageStatsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val lockInChannel = "focuspro/lockin"
    private val triggerChannel = "focuspro/lockin_trigger"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, lockInChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageStatsPermission" -> result.success(hasUsageStatsPermission())
                    "requestUsageStatsPermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "getAppUsageToday" -> {
                        try { result.success(getAppUsageToday()) }
                        catch (e: Exception) { result.error("USAGE_ERROR", e.message, null) }
                    }
                    "startScreenPin" -> {
                        try { startLockTask(); result.success(null) }
                        catch (e: Exception) { result.error("PIN_ERROR", e.message, null) }
                    }
                    "stopScreenPin" -> {
                        try { stopLockTask(); result.success(null) }
                        catch (e: Exception) { result.error("PIN_ERROR", e.message, null) }
                    }
                    "acquireWakeLock" -> {
                        acquireWakeLock(); result.success(null)
                    }
                    "releaseWakeLock" -> {
                        releaseWakeLock(); result.success(null)
                    }
                    "scheduleAlarm" -> {
                        val time = call.argument<String>("time") ?: return@setMethodCallHandler result.error("ARG", "time required", null)
                        val scheduleId = call.argument<Int>("scheduleId") ?: return@setMethodCallHandler result.error("ARG", "scheduleId required", null)
                        scheduleAlarm(time, scheduleId)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val scheduleId = call.argument<Int>("scheduleId") ?: return@setMethodCallHandler result.error("ARG", "scheduleId required", null)
                        cancelAlarm(scheduleId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleLockInTrigger(intent)
    }

    override fun onStart() {
        super.onStart()
        handleLockInTrigger(intent)
    }

    private fun handleLockInTrigger(intent: Intent?) {
        if (intent?.getBooleanExtra("LOCKIN_TRIGGER", false) == true) {
            val scheduleId = intent.getIntExtra("SCHEDULE_ID", -1)
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, triggerChannel)
                    .invokeMethod("onLockInTrigger", if (scheduleId >= 0) scheduleId else null)
            }
        }
    }

    // ── Usage stats ───────────────────────────────────────────────────────────

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getAppUsageToday(): String {
        val usageManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()

        val stats = usageManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, startTime, endTime
        )

        val json = JSONArray()
        stats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .take(20)
            .forEach { stat ->
                val appName = try {
                    val info = packageManager.getApplicationInfo(stat.packageName, 0)
                    packageManager.getApplicationLabel(info).toString()
                } catch (_: PackageManager.NameNotFoundException) {
                    stat.packageName
                }
                val obj = JSONObject()
                obj.put("packageName", stat.packageName)
                obj.put("appName", appName)
                obj.put("totalMinutesToday", stat.totalTimeInForeground / 60000)
                json.put(obj)
            }
        return json.toString()
    }

    // ── Wake lock ─────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = pm.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "focuspro:lockin"
        )
        wakeLock?.acquire(4 * 60 * 60 * 1000L) // max 4h
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
    }

    // ── Alarm scheduling ──────────────────────────────────────────────────────

    private fun scheduleAlarm(timeHHmm: String, scheduleId: Int) {
        val parts = timeHHmm.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: return
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: return

        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(Calendar.getInstance())) add(Calendar.DAY_OF_YEAR, 1)
        }

        val intent = Intent(this, AlarmReceiver::class.java).apply {
            action = "com.example.capstone_front_end.LOCK_IN_ALARM"
            putExtra("SCHEDULE_ID", scheduleId)
        }
        val pending = PendingIntent.getBroadcast(
            this, scheduleId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pending)
        }
    }

    private fun cancelAlarm(scheduleId: Int) {
        val intent = Intent(this, AlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            this, scheduleId, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        pending?.let {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(it)
            it.cancel()
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }
}
