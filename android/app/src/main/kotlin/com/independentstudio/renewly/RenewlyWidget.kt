package com.independentstudio.renewly

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/** Monthly total and the next three bills. Data comes from lib/core/home_widget.dart. */
class RenewlyWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val total = widgetData.getString("total", "") ?: ""
        val today = LocalDate.now()
        // Bills before today are dropped, so the widget stays right between app launches.
        val bills = JSONArray(widgetData.getString("bills", "[]") ?: "[]").let { all ->
            (0 until all.length()).map { all.getJSONObject(it) }
                .filter { !LocalDate.parse(it.getString("date")).isBefore(today) }
                .take(3)
        }
        val rows = listOf(
            Triple(R.id.row1, R.id.name1, R.id.when1) to R.id.amount1,
            Triple(R.id.row2, R.id.name2, R.id.when2) to R.id.amount2,
            Triple(R.id.row3, R.id.name3, R.id.when3) to R.id.amount3,
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.renewly_widget)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            views.setTextViewText(R.id.total, if (total.isEmpty()) "Renewly" else total)
            views.setViewVisibility(R.id.empty, if (bills.isEmpty()) View.VISIBLE else View.GONE)
            rows.forEachIndexed { i, (ids, amountId) ->
                val (rowId, nameId, whenId) = ids
                val bill = bills.getOrNull(i)
                views.setViewVisibility(rowId, if (bill == null) View.GONE else View.VISIBLE)
                if (bill != null) {
                    views.setTextViewText(nameId, bill.getString("name"))
                    views.setTextViewText(whenId, whenLabel(LocalDate.parse(bill.getString("date")), today))
                    views.setTextViewText(amountId, bill.getString("amount"))
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun whenLabel(date: LocalDate, today: LocalDate): String {
        val days = ChronoUnit.DAYS.between(today, date)
        return when {
            days <= 0 -> "Today"
            days == 1L -> "Tomorrow"
            days < 14 -> "In $days days"
            else -> date.format(DateTimeFormatter.ofPattern("MMM d"))
        }
    }
}
