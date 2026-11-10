import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class DirettaScreen extends StatefulWidget {
  const DirettaScreen({super.key});
  @override
  State<DirettaScreen> createState() => _DirettaScreenState();
}

class _DirettaScreenState extends State<DirettaScreen> {
  Timer? _poll;
  Timer? _clock;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    await app.refreshLive();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final st = app.live;

    if (st == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        const PageTitle('🔴', 'Diretta'),
        const PgsCard(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  '📺 Nessuna partita in diretta in questo momento.\nQuando l\'admin avvia lo scout la vedrai qui, azione per azione.',
                  textAlign: TextAlign.center),
            ),
          ),
        ),
        if (app.nextGame() != null) ...[
          const SizedBox(height: 12),
          MatchCard(app.nextGame()!, 'Prossima partita'),
        ],
      ]);
    }

    final g = app.games.where((x) => x.id == st.gid).isEmpty
        ? null
        : app.games.firstWhere((x) => x.id == st.gid);
    final d = deriveLive(st);

    // orologio
    int remaining = st.clockMs;
    if (st.running && st.runStartServer != null) {
      final nowServer = DateTime.now().millisecondsSinceEpoch + app.liveOffset;
      remaining = st.clockMs - (nowServer - st.runStartServer!);
    }
    if (remaining < 0) remaining = 0;

    final homeIsUs = g == null || g.home;
    final homeName = homeIsUs ? 'PGS SALGEN' : g.opponent;
    final awayName = homeIsUs ? (g?.opponent ?? 'Avversari') : 'PGS SALGEN';
    final homeScore = homeIsUs ? d.us : d.opp;
    final awayScore = homeIsUs ? d.opp : d.us;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('🔴', 'Diretta'),
      PgsCard(
        color: st.isFinal ? Colors.grey.shade800 : PgsColors.blue800,
        child: Column(children: [
          Text(
              st.isFinal
                  ? '🏁 FINALE'
                  : '● LIVE  ·  ${periodName(st.period, st.periods)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _teamScore(homeName, homeScore)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(':',
                  style: TextStyle(color: Colors.white, fontSize: 28)),
            ),
            Expanded(child: _teamScore(awayName, awayScore)),
          ]),
          if (!st.isFinal) ...[
            const SizedBox(height: 8),
            Text(fmtClock(remaining),
                style: TextStyle(
                    color: st.running ? PgsColors.orange : Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [])),
          ],
          const SizedBox(height: 4),
          Text(
              'Falli di squadra ${periodName(st.period, st.periods)}: ${d.teamFouls[st.period] ?? 0}'
              '${(d.teamFouls[st.period] ?? 0) >= 5 ? '  ·  BONUS' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('📜 Azioni')),
          ButtonSegment(value: 1, label: Text('📊 Tabellino')),
        ],
        selected: {_tab},
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      ),
      const SizedBox(height: 12),
      if (_tab == 0) _feed(app, st, g) else _box(app, st),
    ]);
  }

  Widget _teamScore(String name, int score) => Column(children: [
        TeamBadge(name, size: 40),
        const SizedBox(height: 4),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
        Text('$score',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900)),
      ]);

  Widget _feed(AppState app, LiveState st, Game? g) {
    final events = st.events.reversed.take(60).toList();
    if (events.isEmpty) {
      return const PgsCard(
          child: Center(child: Text('Palla a due! Ancora nessuna azione.')));
    }
    return PgsCard(
      child: Column(
        children: events.map((e) => _feedLine(app, e, g)).toList(),
      ),
    );
  }

  Widget _feedLine(AppState app, LiveEvent e, Game? g) {
    final t = '${periodName(e.p)} ${fmtClock(e.c)}';
    String body;
    Color color = Colors.black87;
    if (e.k.startsWith('op')) {
      body = '+${e.k.substring(2)} ${g?.opponent ?? 'avversari'}';
      color = Colors.black54;
    } else if (e.k == 'sub') {
      final a = app.player(e.num);
      final b = app.player(e.out);
      body = '🔄 entra #${e.num} ${a?.name ?? ''}, esce #${e.out} ${b?.name ?? ''}';
    } else {
      final p = app.player(e.num);
      final a = kActions[e.k];
      body = '#${e.num} ${p?.name ?? ''} · ${a?.feed ?? e.k}';
      if (e.k == '3m') color = PgsColors.orange;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 68,
            child: Text(t,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text(body,
                style: TextStyle(
                    color: color,
                    fontWeight: e.k == '3m' ? FontWeight.w900 : FontWeight.w600))),
      ]),
    );
  }

  Widget _box(AppState app, LiveState st) {
    final d = deriveLive(st);
    final rows = d.box.entries
        .where((e) => e.value['min']! > 0 || kStatKeys.any((k) => k != 'min' && e.value[k]! > 0))
        .toList()
      ..sort((a, b) => b.value['pts']!.compareTo(a.value['pts']!));
    if (rows.isEmpty) {
      return const PgsCard(child: Text('Ancora nessuna statistica.'));
    }
    return PgsCard(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 32,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 38,
          columns: const [
            DataColumn(label: Text('Giocatore')),
            DataColumn(label: Text('PTS')),
            DataColumn(label: Text('2P')),
            DataColumn(label: Text('3P')),
            DataColumn(label: Text('TL')),
            DataColumn(label: Text('RIM')),
            DataColumn(label: Text('F')),
          ],
          rows: rows.map((e) {
            final s = e.value;
            final p = app.player(e.key);
            return DataRow(cells: [
              DataCell(Text('#${e.key} ${p?.name ?? ''}')),
              DataCell(Text('${s['pts']}',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
              DataCell(Text('${s['p2m']}/${s['p2a']}')),
              DataCell(Text('${s['p3m']}/${s['p3a']}')),
              DataCell(Text('${s['ftm']}/${s['fta']}')),
              DataCell(Text('${s['reb']}')),
              DataCell(Text('${s['pf']}')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
