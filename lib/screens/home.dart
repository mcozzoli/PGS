import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    final ng = app.nextGame();
    final last = app.games.reversed.where((g) => g.played).isEmpty
        ? null
        : app.games.reversed.firstWhere((g) => g.played);

    final official =
        app.games.where((g) => g.official && g.played).toList();
    final w = official.where((g) => g.ourScore! > g.oppScore!).length;
    final l = official.where((g) => g.ourScore! < g.oppScore!).length;

    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _hero(u, w, l),
          if (app.liveOn) ...[
            const SizedBox(height: 12),
            _liveBanner(context, app),
          ],
          if (u.isPlayer && ng != null) ..._playerStatus(app, ng),
          if (!u.isFan && app.board.unread > 0) ...[
            const SizedBox(height: 12),
            StatusBanner(
                '📣',
                app.board.unread == 1
                    ? 'Hai 1 nuova comunicazione in bacheca'
                    : 'Hai ${app.board.unread} nuove comunicazioni in bacheca',
                color: PgsColors.orange),
          ],
          const SizedBox(height: 16),
          if (ng != null)
            MatchCard(ng, 'Prossima partita')
          else
            const PgsCard(
                child: Center(
                    child: Text('🏆 Stagione conclusa!',
                        style: TextStyle(fontWeight: FontWeight.w800)))),
          const SizedBox(height: 12),
          if (last != null)
            MatchCard(last,
                'Ultimo risultato · ${last.won ? 'Vittoria 🎉' : 'Sconfitta'}')
          else
            const PgsCard(
                child: Center(
                    child: Text('🏀 Ancora nessun risultato',
                        style: TextStyle(fontWeight: FontWeight.w700)))),
          if (u.isPlayer) ..._miniStats(app, u.num!),
          const SizedBox(height: 20),
          const Center(
            child: Text('Forza Salgen! 💙🧡',
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: PgsColors.blue800)),
          ),
        ],
      ),
    );
  }

  Widget _hero(dynamic u, int w, int l) {
    final title = u.isAdmin
        ? 'Ciao Admin!'
        : u.isCoach
            ? 'Ciao Coach ${u.name}!'
            : u.isFan
                ? 'Ciao tifoso!'
                : 'Ciao ${u.name}!';
    final sub = u.isCoach
        ? 'La panchina ti aspetta: scegli convocati e quintetto.'
        : u.isAdmin
            ? 'Carica i referti dopo ogni partita.'
            : u.isFan
                ? 'Benvenuto nella curva digitale della PGS Salgen.'
                : 'Benvenuto nello spogliatoio digitale.';
    return PgsCard(
      color: PgsColors.blue800,
      child: Row(children: [
        if (u.isMember)
          Text('#${u.num}',
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: PgsColors.orange))
        else
          const Text('🏀', style: TextStyle(fontSize: 34)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(color: Colors.white70)),
            if (!u.isFan) ...[
              const SizedBox(height: 6),
              Text('Record stagione: ${w}V – ${l}P',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _liveBanner(BuildContext context, AppState app) {
    final st = app.live!;
    final g = app.games.where((x) => x.id == st.gid).isEmpty
        ? null
        : app.games.firstWhere((x) => x.id == st.gid);
    final d = deriveLive(st);
    return StatusBanner(
      '🔴',
      'IN DIRETTA · ${g != null ? 'PGS ${d.us} – ${d.opp} ${g.opponent}' : ''} · ${periodName(st.period, st.periods)}',
      color: Colors.red,
    );
  }

  List<Widget> _playerStatus(AppState app, dynamic ng) {
    final L = app.myLineup(ng.id);
    Widget banner;
    if (L == null) {
      banner = const StatusBanner(
          '⏳', 'Il coach non ha ancora diramato le convocazioni.',
          color: Colors.blueGrey);
    } else if (L.starter != null) {
      final pos = kPositions.firstWhere((p) => p.key == L.starter);
      banner = StatusBanner(
          '⭐', 'Sei nel QUINTETTO come ${pos.label}! Fatti trovare pronto!',
          color: Colors.green);
    } else if (L.convocato) {
      banner = const StatusBanner('✅', 'Sei CONVOCATO per la prossima partita!',
          color: Colors.green);
    } else {
      banner = const StatusBanner(
          '🙌', 'Questa volta non sei tra i convocati. Tifa forte!',
          color: Colors.orange);
    }
    return [const SizedBox(height: 12), banner];
  }

  List<Widget> _miniStats(AppState app, String num) {
    final ls = app.playerLines(num);
    if (ls.isEmpty) return [];
    final t = totals(ls.map((e) => e.value));
    final n = ls.length;
    return [
      const SectionTitle('Il tuo rendimento'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: [
          StatTile('$n', 'Partite'),
          StatTile('${r1(t['pts']! / n)}', 'Punti / g', hot: true),
          StatTile('${r1(t['reb']! / n)}', 'Rimbalzi / g'),
          StatTile('${r1(t['ast']! / n)}', 'Assist / g'),
        ],
      ),
    ];
  }
}
