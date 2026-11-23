package com.example.mobile_project

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONArray
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

class TodayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val now = LocalDateTime.now()
        val prefs = context.getSharedPreferences("today_widget", Context.MODE_PRIVATE)
        val entries = if (prefs.getString("date", "") == now.toLocalDate().toString())
            JSONArray(prefs.getString("entries", "[]")) else JSONArray()
        val minute = now.hour * 60 + now.minute
        val next = (0 until entries.length()).map { entries.getJSONObject(it) }.firstOrNull { it.getInt("end") > minute }
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        views.setTextViewText(R.id.widget_date, now.format(DateTimeFormatter.ofPattern("EEE, MMM d", Locale.getDefault())))
        views.setTextViewText(R.id.widget_activity, next?.getString("title") ?: "Open your day")
        val intent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        views.setOnClickPendingIntent(R.id.widget_open, PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.updateAppWidget(ids, views)
    }

    companion object {
        fun publish(context: Context, date: String?, entries: List<*>?) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))
            val prefs = context.getSharedPreferences("today_widget", Context.MODE_PRIVATE).edit().clear()
            if (date != null) {
                prefs.putString("date", date).putString("entries", JSONArray(entries ?: emptyList<Any>()).toString())
            }
            prefs.apply()
            if (ids.isNotEmpty()) TodayWidget().onUpdate(context, manager, ids)
        }
    }
}
