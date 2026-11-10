import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

const _phases = [
  ['Andata', 'Girone di andata'],
  ['Ritorno', 'Girone di ritorno'],
  ['Coppa/Torneo', 'Coppa / Torneo'],
  ['Amichevole', 'Amichevoli'],
];

class CalendarioScreen extends StatelessWidget {
  const CalendarioScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ng = app.nextGame();
    final known = _phases.map((p) => p[0]).toList();
    final extra = app.games
        .map((g) => g.phase)
        .toSet()
        .where((p) => !known.contains(p))
        .map((p) => [p, p]);
    final groups = [..._phases, ...extra];

    final children = <Widget>[
      PageTitle('📅', app.user!.isFan ? 'Prossime partite' : 'Calendario 2026/27'),
    ];
    for (final grp in groups) {
      final list = app.games.where((g) => g.phase == grp[0]).toList();
      if (list.isEmpty) continue;
      children.add(SectionTitle(grp[1]));
      for (final g in list) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MatchRow(g, isNext: ng?.id == g.id),
        ));
      }
    }
    if (children.length == 1) {
      children.add(const PgsCard(
          child: Center(child: Text('Nessuna partita in calendario.'))));
    }

    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

/// Riga partita riutilizzata da calendario e risultati.
class MatchRow extends StatelessWidget {
  final Game game;
  final bool isNext;
  final VoidCallback? onTap;
  const MatchRow(this.game, {super.key, this.isNext = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final d = game.dateTime;
    final t = game.teams;
    final right = <Widget>[];
    if (game.phase == 'Amichevole') {
      right.add(const Pill('🤝 Amichevole', color: Colors.teal));
    } else if (game.phase == 'Coppa/Torneo') {
      right.add(const Pill('🏆 Coppa', color: Colors.purple));
    }
    right.add(Pill(game.home ? '🏠 Casa' : '🚌 Trasferta',
        color: game.home ? PgsColors.blue : PgsColors.orange));

    if (game.played) {
      right.add(Text(
          '${game.home ? game.ourScore : game.oppScore} – ${game.home ? game.oppScore : game.ourScore}',
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 16)));
      right.add(Pill(game.won ? 'Vinta' : 'Persa',
          color: game.won ? Colors.green : Colors.red));
    } else if (app.user!.isPlayer) {
      final L = app.myLineup(game.id);
      if (L != null) {
        if (L.starter != null) {
          right.add(const Pill('⭐ Quintetto', color: Colors.amber));
        } else if (L.convocato) {
          right.add(const Pill('✅ Convocato', color: Colors.green));
        } else {
          right.add(const Pill('Non convocato', color: Colors.grey));
        }
        if (L.captain) right.add(const Pill('Ⓒ Capitano', color: PgsColors.orange));
      }
    }

    return PgsCard(
      onTap: onTap,
      color: isNext ? PgsColors.orange.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: PgsColors.blue800,
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('${d.day}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            Text(mese(d),
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t[0]} – ${t[1]}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, children: [
                  Text('⏰ ore ${game.time}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  InkWell(
                    onTap: () => launchUrl(
                        Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(game.venue)}'),
                        mode: LaunchMode.externalApplication),
                    child: Text('📍 ${game.venue}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: PgsColors.blue,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: right),
              ]),
        ),
      ]),
    );
  }
}
