import 'package:home_widget/home_widget.dart';
import 'app_state.dart';
import 'logic.dart';

/// Scrive nel widget home i dati correnti (prossima partita / diretta /
/// classifica / ultimo risultato) e ne richiede l'aggiornamento.
///
/// Lato nativo i widget leggono queste chiavi:
///  w_label, w_title, w_match, w_meta, w_extra
Future<void> syncHomeWidget(AppState app) async {
  try {
    String label, title, match = '', meta = '', extra = '';

    if (app.liveOn && app.live != null) {
      final d = deriveLive(app.live!);
      final g = app.games.where((x) => x.id == app.live!.gid).isEmpty
          ? null
          : app.games.firstWhere((x) => x.id == app.live!.gid);
      label = '🔴 In diretta';
      title = 'PGS ${d.us} – ${d.opp}';
      match = g != null ? 'vs ${g.opponent}' : '';
      meta = periodName(app.live!.period, app.live!.periods);
    } else {
      final ng = app.nextGame();
      if (ng != null) {
        final dt = ng.dateTime;
        label = ng.official ? '🏀 Prossima partita' : '🤝 Prossima (amichevole)';
        title = '${weekday(dt).substring(0, 3).toUpperCase()} ${dt.day} ${mese(dt)}';
        match = 'PGS Salgen · ${ng.opponent}';
        meta = 'ore ${ng.time} · ${ng.home ? '🏠 Casa' : '🚌 Trasferta'}';
      } else if (app.loggedIn) {
        label = '🏀 PGS Salgen';
        title = 'Nessuna partita';
        match = 'in programma';
      } else {
        label = '🏀 PGS Salgen';
        title = 'Apri l\'app';
        match = 'per vedere le partite';
      }
    }

    // classifica (posizione nostra)
    final teams = [...app.standings.teams];
    if (teams.isNotEmpty) {
      teams.sort((a, b) => b.pts != a.pts
          ? b.pts - a.pts
          : (b.pf - b.ps) - (a.pf - a.ps));
      final idx = teams.indexWhere((t) => t.us);
      if (idx >= 0) {
        extra = '${idx + 1}ª su ${teams.length} · ${teams[idx].pts} pt';
      }
    }

    await HomeWidget.saveWidgetData<String>('w_label', label);
    await HomeWidget.saveWidgetData<String>('w_title', title);
    await HomeWidget.saveWidgetData<String>('w_match', match);
    await HomeWidget.saveWidgetData<String>('w_meta', meta);
    await HomeWidget.saveWidgetData<String>('w_extra', extra);
    await HomeWidget.updateWidget(androidName: 'PgsWidgetProvider');
  } catch (_) {
    // il widget non è critico: ignoriamo gli errori
  }
}
