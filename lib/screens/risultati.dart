import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'calendario.dart';
import 'classifica.dart';

class RisultatiScreen extends StatefulWidget {
  const RisultatiScreen({super.key});
  @override
  State<RisultatiScreen> createState() => _RisultatiScreenState();
}

class _RisultatiScreenState extends State<RisultatiScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const PageTitle('🏆', 'Risultati'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('🏀 Partite')),
            ButtonSegment(value: 1, label: Text('📊 Classifica')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 12),
        if (_tab == 1) const ClassificaView() else ..._partite(app),
      ]),
    );
  }

  List<Widget> _partite(AppState app) {
    final all = app.games.where((g) => g.played).toList();
    final done = all.where((g) => g.official).toList();
    final w = done.where((g) => g.ourScore! > g.oppScore!).length;
    final pf = done.fold<int>(0, (a, g) => a + g.ourScore!);
    final ps = done.fold<int>(0, (a, g) => a + g.oppScore!);
    final n = done.length;

    return [
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: [
          StatTile('$w', 'Vittorie', hot: true),
          StatTile('${n - w}', 'Sconfitte'),
          StatTile(n > 0 ? '${r1(pf / n)}' : '0', 'Fatti / g'),
          StatTile(n > 0 ? '${r1(ps / n)}' : '0', 'Subiti / g'),
        ],
      ),
      const SectionTitle('Partite giocate'),
      if (all.isEmpty)
        const PgsCard(
            child: Center(child: Text('Nessuna partita giocata finora.')))
      else
        ...all.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExpandableGame(g),
            )),
      if (all.length > done.length)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Le amichevoli non contano nel record.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
    ];
  }
}

class _ExpandableGame extends StatefulWidget {
  final Game game;
  const _ExpandableGame(this.game);
  @override
  State<_ExpandableGame> createState() => _ExpandableGameState();
}

class _ExpandableGameState extends State<_ExpandableGame> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(children: [
      MatchRow(widget.game, onTap: () => setState(() => _open = !_open)),
      if (_open)
        PgsCard(
          padding: const EdgeInsets.all(12),
          child: _boxScore(app, widget.game),
        ),
    ]);
  }

  Widget _boxScore(AppState app, Game g) {
    final st = app.stats[g.id];
    if (st == null || st.isEmpty) {
      return const Text('Referto non ancora caricato.',
          style: TextStyle(color: Colors.black54));
    }
    final rows = st.entries.toList()
      ..sort((a, b) =>
          ((b.value['pts'] as num?) ?? 0).compareTo((a.value['pts'] as num?) ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tabellino',
          style: TextStyle(fontWeight: FontWeight.w900, color: PgsColors.blue800)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 32,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 40,
          columns: const [
            DataColumn(label: Text('Giocatore')),
            DataColumn(label: Text('PTS')),
            DataColumn(label: Text('2P')),
            DataColumn(label: Text('3P')),
            DataColumn(label: Text('TL')),
            DataColumn(label: Text('RIM')),
            DataColumn(label: Text('AST')),
            DataColumn(label: Text('VAL')),
          ],
          rows: rows.map((e) {
            final s = e.value;
            final p = app.player(e.key);
            num v(String k) => (s[k] as num?) ?? 0;
            return DataRow(cells: [
              DataCell(Text('#${e.key} ${p?.name ?? '?'}')),
              DataCell(Text('${v('pts')}',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
              DataCell(Text('${v('p2m')}/${v('p2a')}')),
              DataCell(Text('${v('p3m')}/${v('p3a')}')),
              DataCell(Text('${v('ftm')}/${v('fta')}')),
              DataCell(Text('${v('reb')}')),
              DataCell(Text('${v('ast')}')),
              DataCell(Text('${valutazione(s)}')),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}
