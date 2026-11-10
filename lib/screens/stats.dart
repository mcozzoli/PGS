import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../theme.dart';
import '../widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final staff = !app.user!.isPlayer;
    final roster = app.roster();
    final pnum = staff
        ? (_selected ?? (roster.isNotEmpty ? roster.first.num : null))
        : app.user!.num;

    if (pnum == null) {
      return const Center(child: Text('Nessun giocatore.'));
    }
    final p = app.player(pnum);
    final ls = app.playerLines(pnum);
    final n = ls.length;
    final t = totals(ls.map((e) => e.value));

    return RefreshIndicator(
      onRefresh: () => app.refreshStats(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const PageTitle('📊', 'Statistiche'),
        if (staff)
          PgsCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButton<String>(
              value: pnum,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: roster
                  .map((x) => DropdownMenuItem(
                      value: x.num, child: Text('#${x.num} ${x.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
          ),
        const SizedBox(height: 12),
        PgsCard(
          color: PgsColors.blue800,
          child: Row(children: [
            Jersey(p?.num ?? pnum, name: p?.name ?? '', size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p?.name ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const Text('Stagione 2026/27',
                        style: TextStyle(color: Colors.white70)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (n == 0)
          const PgsCard(
              child: Center(
                  child: Text(
                      '🏀 Nessuna statistica ancora.\nAppariranno dopo il primo referto.',
                      textAlign: TextAlign.center)))
        else ...[
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
              StatTile('${r1(t['stl']! / n)}', 'Recuperi / g'),
              StatTile('${r1(t['blk']! / n)}', 'Stoppate / g'),
              StatTile('${r1(t['min']! / n)}', 'Minuti / g'),
              StatTile(
                  '${r1(ls.map((e) => valutazione(e.value)).fold<num>(0, (a, v) => a + v) / n)}',
                  'Valut. / g',
                  hot: true),
            ],
          ),
          const SectionTitle('Al tiro'),
          Row(children: [
            Expanded(child: _shot('Tiri da 2', t['p2m']!, t['p2a']!)),
            const SizedBox(width: 8),
            Expanded(child: _shot('Tiri da 3', t['p3m']!, t['p3a']!)),
            const SizedBox(width: 8),
            Expanded(child: _shot('Liberi', t['ftm']!, t['fta']!)),
          ]),
          const SectionTitle('Partita per partita'),
          PgsCard(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 14,
                headingRowHeight: 32,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('Partita')),
                  DataColumn(label: Text('MIN')),
                  DataColumn(label: Text('PTS')),
                  DataColumn(label: Text('2P')),
                  DataColumn(label: Text('3P')),
                  DataColumn(label: Text('TL')),
                  DataColumn(label: Text('RIM')),
                  DataColumn(label: Text('AST')),
                  DataColumn(label: Text('VAL')),
                ],
                rows: ls.map((e) {
                  final g = e.key;
                  final s = e.value;
                  final d = g.dateTime;
                  num v(String k) => (s[k] as num?) ?? 0;
                  return DataRow(cells: [
                    DataCell(Text(
                        '${d.day} ${mese(d)} ${g.home ? 'vs' : '@'} ${g.opponent}')),
                    DataCell(Text('${v('min')}')),
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
          ),
        ],
      ]),
    );
  }

  Widget _shot(String label, num made, num att) {
    final p = pct(made, att);
    return PgsCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(children: [
        Text(p == null ? '–' : '$p%',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: PgsColors.blue800)),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text('$made/$att',
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
    );
  }
}
