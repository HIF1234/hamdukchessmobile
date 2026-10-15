import 'package:home_widget/home_widget.dart';

/// Pushes the daily puzzle's rating and the player's streak to the home-screen widget
/// (android/.../HamdukWidgetProvider.kt). Called whenever Play's daily puzzle card loads;
/// best-effort and silent on any failure (no widget added, or a non-Android platform).
Future<void> syncHomeWidget({required int? rating, required int streak}) async {
  try {
    await HomeWidget.saveWidgetData<String>('puzzleRating', rating?.toString());
    await HomeWidget.saveWidgetData<String>('puzzleStreak', streak.toString());
    await HomeWidget.updateWidget(androidName: 'HamdukWidgetProvider');
  } catch (_) {
    // Nothing to show for -- there may be no widget added, or this isn't Android.
  }
}
