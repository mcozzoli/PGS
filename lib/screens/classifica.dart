import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

const _cols = [
  ['pts', 'PT'],
  ['g', 'G'],
  ['w', 'V'],
  ['l', 'P'],
  ['pf', 'CF'],
  ['ps', 'CS'],
];

List<StandingsTeam> _sorted(List<StandingsTeam> teams) {
  final t = [...teams];
  t.sort((a, b) {
    if (b.pts != a.pts) return b.pts - a.pts;
    if (b.diff != a.diff) return b.diff - a.diff;
    if (b.pf != a.pf) return b.pf - a.pf;
    return a.name.compareTo(b.name);
  });
  return t;
}

class ClassificaScreen extends StatelessWidget {
  const ClassificaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(padding: const EdgeInsets.all(16), children: const [
        PageTitle('📊', 'Classifica'),
        ClassificaView(),
      ]),
    );
  }
}

/// Tabella classifica (condivisa tra pagina e tab risultati).
class ClassificaView extends StatelessWidget {
  const ClassificaView({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final rows = _sorted(app.standings.teams);
    final medals = ['🥇', '🥈', '🥉'];

    return PgsCard(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('📊 Classifica non ancora disponibile.'),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columns: [
                const DataColumn(label: Text('#')),
                const DataColumn(label: Text('Squadra')),
                ..._cols.map((c) => DataColumn(
                    label: Text(c[1],
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
                const DataColumn(label: Text('+/−')),
              ],
              rows: List.generate(rows.length, (i) {
                final t = rows[i];
                return DataRow(
                  color: t.us
                      ? WidgetStatePropertyAll(
                          PgsColors.orange.withValues(alpha: 0.12))
                      : null,
                  cells: [
                    DataCell(Text(i < 3 ? medals[i] : '${i + 1}')),
                    DataCell(Text(t.name,
                        style: TextStyle(
                            fontWeight:
                                t.us ? FontWeight.w900 : FontWeight.w600))),
                    ..._cols.map((c) => DataCell(Text(
                        '${_field(t, c[0])}',
                        style: TextStyle(
                            fontWeight: c[0] == 'pts'
                                ? FontWeight.w900
                                : FontWeight.normal)))),
                    DataCell(Text('${t.diff > 0 ? '+' : ''}${t.diff}',
                        style: TextStyle(
                            color: t.diff > 0
                                ? Colors.green
                                : t.diff < 0
                                    ? Colors.red
                                    : Colors.black54))),
                  ],
                );
              }),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
              'PT punti · G giocate · V vinte · P perse · CF canestri fatti · CS subiti',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ),
        if (app.user!.isAdmin) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: PgsColors.blue),
              onPressed: () => _openEditor(context, app),
              icon: const Icon(Icons.edit),
              label: const Text('Modifica classifica'),
            ),
          ),
        ],
      ]),
    );
  }

  int _field(StandingsTeam t, String k) => switch (k) {
        'pts' => t.pts,
        'g' => t.g,
        'w' => t.w,
        'l' => t.l,
        'pf' => t.pf,
        'ps' => t.ps,
        _ => 0,
      };

  void _openEditor(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StandingsEditor(app: app),
    );
  }
}

class _StandingsEditor extends StatefulWidget {
  final AppState app;
  const _StandingsEditor({required this.app});
  @override
  State<_StandingsEditor> createState() => _StandingsEditorState();
}

class _StandingsEditorState extends State<_StandingsEditor> {
  late List<StandingsTeam> draft;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    draft = widget.app.standings.teams.map((t) => t.copy()).toList();
  }

  void _bump(StandingsTeam t, String k, int d) {
    setState(() {
      switch (k) {
        case 'pts':
          t.pts = (t.pts + d).clamp(0, 9999);
        case 'g':
          t.g = (t.g + d).clamp(0, 9999);
        case 'w':
          t.w = (t.w + d).clamp(0, 9999);
        case 'l':
          t.l = (t.l + d).clamp(0, 9999);
        case 'pf':
          t.pf = (t.pf + d).clamp(0, 9999);
        case 'ps':
          t.ps = (t.ps + d).clamp(0, 9999);
      }
    });
  }

  int _val(StandingsTeam t, String k) => switch (k) {
        'pts' => t.pts,
        'g' => t.g,
        'w' => t.w,
        'l' => t.l,
        'pf' => t.pf,
        'ps' => t.ps,
        _ => 0,
      };

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await widget.app.api.request('/standings',
          method: 'PUT', body: {'teams': draft.map((t) => t.toJson()).toList()});
      widget.app.standings =
          Standings.fromJson(Map<String, dynamic>.from(r));
      widget.app.touch();
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Classifica aggiornata 📊');
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => Column(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('✏️ Modifica classifica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: draft
                .map((t) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t.us ? '🏀 ' : ''}${t.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: _cols
                                  .map((c) => _stepper(t, c[0], c[1]))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('💾 Salva')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _stepper(StandingsTeam t, String k, String label) {
    return Column(children: [
      Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
            onTap: () => _bump(t, k, -1),
            child: const Icon(Icons.remove_circle_outline, size: 22)),
        SizedBox(
            width: 30,
            child: Text('${_val(t, k)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        InkWell(
            onTap: () => _bump(t, k, 1),
            child: const Icon(Icons.add_circle_outline, size: 22)),
      ]),
    ]);
  }
}
