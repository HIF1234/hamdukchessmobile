package ng.com.hamduk.chess

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget: today's puzzle rating and the player's streak, synced from Dart
/// (lib/core/home_widget_sync.dart) via HomeWidget.saveWidgetData whenever Play's daily
/// puzzle card loads. Tapping it opens the app; it doesn't deep-link into the puzzle itself.
class HamdukWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.hamduk_widget).apply {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.hamduk_widget_root, pendingIntent)

            val rating = widgetData.getString("puzzleRating", null)
            setTextViewText(R.id.hamduk_widget_rating, if (rating != null) "Rated $rating" else "Daily puzzle")

            val streak = widgetData.getString("puzzleStreak", null)?.toIntOrNull() ?: 0
            setTextViewText(
                R.id.hamduk_widget_streak,
                if (streak > 0) "🔥 $streak day streak" else "Tap to solve today's puzzle",
            )
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
