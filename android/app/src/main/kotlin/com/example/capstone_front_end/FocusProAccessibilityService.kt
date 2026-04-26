package com.example.capstone_front_end

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.CopyOnWriteArrayList

/**
 * FocusProAccessibilityService
 *
 * Runs silently in the background. Every time the user opens a different app
 * or navigates to a different screen, Android fires onAccessibilityEvent().
 *
 * Two things happen on each event:
 *  1. currentPackage / currentActivity are updated (for instant reads from MainActivity).
 *  2. The event is appended to eventBuffer — a thread-safe list that Flutter
 *     drains every 30 seconds and sends to the backend in one batch POST.
 */
class FocusProAccessibilityService : AccessibilityService() {

    /** One captured app-switch event. */
    data class ScreenEvent(
        val packageName: String,
        val appName: String,
        val activityName: String,
        val startedAt: String   // ISO-8601, e.g. "2024-05-01T08:30:00"
    )

    companion object {
        private val ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME

        /** The package currently visible to the user. */
        var currentPackage: String = ""
            private set

        /** The activity/screen currently visible. */
        var currentActivity: String = ""
            private set

        /** True while the service is running. */
        var isRunning: Boolean = false
            private set

        /**
         * Thread-safe buffer of events waiting to be flushed to the backend.
         * Flutter calls drainEvents() which empties this and returns the contents.
         */
        val eventBuffer: CopyOnWriteArrayList<ScreenEvent> = CopyOnWriteArrayList()

        /**
         * Removes and returns all buffered events atomically.
         * Called from MainActivity on the "drainEvents" MethodChannel method.
         */
        fun drainEvents(): List<ScreenEvent> {
            if (eventBuffer.isEmpty()) return emptyList()
            val snapshot = eventBuffer.toList()
            eventBuffer.clear()
            return snapshot
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true

        serviceInfo = serviceInfo?.also { info ->
            info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            info.flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            info.notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        val cls = event.className?.toString() ?: ""

        // Skip system UI overlays
        if (pkg == "com.android.systemui") return
        // Skip if nothing changed
        if (pkg == currentPackage && cls == currentActivity) return

        currentPackage = pkg
        currentActivity = cls

        // Resolve human-readable app name
        val appName = try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            pkg
        }

        // Buffer the event for background sync to the backend
        eventBuffer.add(
            ScreenEvent(
                packageName = pkg,
                appName = appName,
                activityName = cls,
                startedAt = LocalDateTime.now().format(ISO)
            )
        )

        // Keep the buffer from growing too large if Flutter is slow to drain
        if (eventBuffer.size > 500) {
            eventBuffer.removeAt(0)
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
