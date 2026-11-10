package it.pgssalgen.pgs

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget home della PGS Salgen: mostra prossima partita / diretta / classifica.
 * I dati sono scritti dall'app Flutter tramite il pacchetto home_widget.
 */
class PgsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pgs_widget).apply {
                setTextViewText(R.id.w_label, widgetData.getString("w_label", "🏀 PGS Salgen"))
                setTextViewText(R.id.w_title, widgetData.getString("w_title", "Apri l'app"))
                setTextViewText(R.id.w_match, widgetData.getString("w_match", ""))
                setTextViewText(R.id.w_meta, widgetData.getString("w_meta", ""))

                val extra = widgetData.getString("w_extra", "") ?: ""
                if (extra.isEmpty()) {
                    setViewVisibility(R.id.w_extra, android.view.View.GONE)
                } else {
                    setViewVisibility(R.id.w_extra, android.view.View.VISIBLE)
                    setTextViewText(R.id.w_extra, "📊 $extra")
                }

                // Tap sul widget -> apre l'app
                val intent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.w_root, intent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
