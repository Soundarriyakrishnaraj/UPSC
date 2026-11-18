
package com.example.upsc_preparation_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class StreakWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS = "test11_widget_data"
        private const val KEY_STREAK = "current_streak"
        private const val KEY_TESTS = "completed_tests"
        private const val KEY_TODAY = "today_recorded"

        fun updateWidget(
            context: Context,
            currentStreak: Int,
            testCount: Int,
            todayRecorded: Boolean
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit()
                .putInt(KEY_STREAK, currentStreak.coerceAtLeast(0))
                .putInt(KEY_TESTS, testCount.coerceAtLeast(0))
                .putBoolean(KEY_TODAY, todayRecorded)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, StreakWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)

            for (id in ids) {
                updateOneWidget(context, manager, id)
            }
        }

        fun clearWidget(context: Context) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().clear().apply()

            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, StreakWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)

            for (id in ids) {
                updateOneWidget(context, manager, id)
            }
        }

        private fun updateOneWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

            val streak = prefs.getInt(KEY_STREAK, 0)
            val tests = prefs.getInt(KEY_TESTS, 0)
            val today = prefs.getBoolean(KEY_TODAY, false)

            val views = RemoteViews(context.packageName, R.layout.widget_streak)

            views.setTextViewText(R.id.widget_streak_count, streak.toString())
            views.setTextViewText(R.id.widget_test_count, tests.toString())
            views.setTextViewText(
                R.id.widget_today_status,
                if (today) "DONE TODAY" else "TODAY"
            )

            val intent = Intent(context, MainActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_streak_count, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_test_count, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_today_status, pendingIntent)
            views.setOnClickPendingIntent(android.R.id.content, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateOneWidget(context, appWidgetManager, id)
        }
    }
}
