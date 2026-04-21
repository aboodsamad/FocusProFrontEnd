package com.example.capstone_front_end

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getIntExtra("SCHEDULE_ID", -1)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("LOCKIN_TRIGGER", true)
            if (scheduleId >= 0) putExtra("SCHEDULE_ID", scheduleId)
        }
        context.startActivity(launchIntent)
    }
}
