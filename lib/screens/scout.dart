import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key});
  @override
  State<ScoutScreen> createState() => _ScoutScreenState();
}

class _ScoutScreenState extends State<ScoutScreen> {
  Map<String, dynamic>? st; // stato di lavoro mutabile (come l'oggetto JS)
  Timer? _saveT;
  Timer? _tick;
  final _rnd = Random();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    // riprendi dallo stato server se è in corso
    final live = app.live;
    if (live != null && live.isLive) {
      st = {
        'gid': live.gid,
        'status': live.status,
        'period': live.period,
        'periods': live.periods,
        'periodLen': live.periodLen,
        'clockMs': live.clockMs,
        'running': live.running,
        'runStart': live.running && live.runStartServer != null
            ? live.runStartServer! - app.liveOffset
            : null,
        'onCourt': [...live.onCourt],
        'roster': [...live.roster],
        'played': {...live.played},
        'events': live.events.map((e) => e.toJson()).toList(),
        'startedAt': DateTime.now().millisecondsSinceEpoch,
      };
    }
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (st != null && st!['running'] == true && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _saveT?.cancel();
    _tick?.cancel();
    if (st != null) {
      _commit();
      _save();
    }
    super.dispose();
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;
  String _uid() => _rnd.nextInt(1 << 32).toRadixString(36);

  void _commit() {
    if (st == null || st!['running'] != true) return;
    final runStart = st!['runStart'] as int?;
    if (runStart == null) return;
    final el = min(_now - runStart, st!['clockMs'] as int);
    st!['clockMs'] = (st!['clockMs'] as int) - el;
    st!['runStart'] = _now;
    final played = Map<String, int>.from(st!['played'] as Map);
    for (final n in (st!['onCourt'] as List).cast<String>()) {
      played[n] = (played[n] ?? 0) + el;
    }
    st!['played'] = played;
    if ((st!['clockMs'] as int) <= 0) {
      st!['clockMs'] = 0;
      st!['running'] = false;
      st!['runStart'] = null;
    }
  }

  int get _remaining {
    if (st == null) return 0;
    var ms = st!['clockMs'] as int;
    if (st!['running'] == true && st!['runStart'] != null) {
      ms -= _now - (st!['runStart'] as int);
    }
    return ms < 0 ? 0 : ms;
  }

  void _saveSoon() {
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    if (st == null) return;
    _commit();
    final app = context.read<AppState>();
    final state = Map<String, dynamic>.from(st!)
      ..remove('runStart')
      ..remove('announceStart');
    try {
      await app.api.request('/live/${st!['gid']}', method: 'PUT', body: {
        'state': state,
        'runElapsed': 0,
        'announceStart': st!['announceStart'] == true,
      });
      st!['announceStart'] = false;
    } catch (_) {
      // riproveremo al prossimo salvataggio
    }
  }

  void _record(String k, String n) {
    _commit();
    (st!['events'] as List).add({
      'id': _uid(),
      'p': st!['period'],
      'c': st!['clockMs'],
      'num': n,
      'k': k,
      'ts': _now,
    });
    _saveSoon();
    setState(() {});
  }

  void _opp(int pts) {
    _commit();
    (st!['events'] as List).add({
      'id': _uid(),
      'p': st!['period'],
      'c': st!['clockMs'],
      'num': null,
      'k': 'op$pts',
      'ts': _now,
    });
    _saveSoon();
    setState(() {});
  }

  void _undo() {
    final events = st!['events'] as List;
    if (events.isEmpty) return;
    final e = events.removeLast() as Map;
    if (e['k'] == 'sub') {
      st!['onCourt'] = (st!['onCourt'] as List)
          .map((x) => x == e['num'] ? e['out'] : x)
          .toList();
    }
    _saveSoon();
    setState(() {});
  }

  void _toggleClock() {
    if (st!['running'] == true) {
      _commit();
      st!['running'] = false;
      st!['runStart'] = null;
    } else {
      if ((st!['clockMs'] as int) <= 0) {
        toast(context, 'Tempo scaduto: passa al periodo successivo', error: true);
        return;
      }
      st!['running'] = true;
      st!['runStart'] = _now;
    }
    _saveSoon();
    setState(() {});
  }

  void _changePeriod(int delta) {
    _commit();
    final p = (st!['period'] as int) + delta;
    if (p < 1) return;
    st!['period'] = p;
    st!['clockMs'] = st!['periodLen'];
    st!['running'] = false;
    st!['runStart'] = null;
    _saveSoon();
    setState(() {});
  }

  Future<void> _sub() async {
    final app = context.read<AppState>();
    final onCourt = (st!['onCourt'] as List).cast<String>();
    final bench = (st!['roster'] as List)
        .cast<String>()
        .where((n) => !onCourt.contains(n))
        .toList();
    final out = await _pickPlayer(app, onCourt, 'Chi esce?');
    if (out == null) return;
    if (!mounted) return;
    final inn = await _pickPlayer(app, bench, 'Chi entra?');
    if (inn == null) return;
    _commit();
    st!['onCourt'] =
        onCourt.map((x) => x == out ? inn : x).toList();
    (st!['events'] as List).add({
      'id': _uid(),
      'p': st!['period'],
      'c': st!['clockMs'],
      'num': inn,
      'out': out,
      'k': 'sub',
      'ts': _now,
    });
    _saveSoon();
    setState(() {});
  }

  Future<String?> _pickPlayer(
      AppState app, List<String> nums, String title) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          ...nums.map((n) {
            final p = app.player(n);
            return ListTile(
              title: Text('#$n ${p?.name ?? ''}'),
              onTap: () => Navigator.pop(context, n),
            );
          }),
          if (nums.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nessun giocatore disponibile.')),
        ]),
      ),
    );
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terminare la partita?'),
        content: const Text(
            'Lo stato diventa FINALE e le statistiche vengono salvate nelle schede.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Termina')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final app = context.read<AppState>();
    _commit();
    st!['status'] = 'final';
    st!['running'] = false;
    st!['runStart'] = null;
    await _save();
    await app.refreshStats();
    await app.refreshLive();
    if (mounted) {
      setState(() => st = null);
      toast(context, 'Partita terminata 🏁');
    }
  }

  String? _sel;
  String? _pend;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (st == null) return _setup(app);
    return _board(app);
  }

  // ---------- SETUP ----------
  Widget _setup(AppState app) {
    return _ScoutSetup(
      app: app,
      onStart: (gid, periodLen, roster, five, announce) {
        setState(() {
          st = {
            'gid': gid,
            'status': 'live',
            'period': 1,
            'periods': 4,
            'periodLen': periodLen,
            'clockMs': periodLen,
            'running': false,
            'runStart': null,
            'onCourt': [...five],
            'roster': [...roster],
            'played': <String, int>{},
            'events': <Map<String, dynamic>>[],
            'startedAt': _now,
            'announceStart': announce,
          };
        });
        _save();
      },
    );
  }

  // ---------- BOARD ----------
  Widget _board(AppState app) {
    final onCourt = (st!['onCourt'] as List).cast<String>();
    final derived = deriveLive(LiveState.fromJson(Map<String, dynamic>.from(st!)));
    final actions = [
      ('2m', '2 ✓'),
      ('2x', '2 ✗'),
      ('3m', '3 ✓'),
      ('3x', '3 ✗'),
      ('1m', 'TL ✓'),
      ('1x', 'TL ✗'),
      ('or', 'R.Off'),
      ('dr', 'R.Dif'),
      ('as', 'Assist'),
      ('st', 'Recup.'),
      ('bk', 'Stop.'),
      ('to', 'Palla p.'),
      ('pf', 'Fallo'),
    ];

    return Column(children: [
      // scoreboard
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: PgsColors.blue800,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('PGS ${derived.us}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const Text('  –  ',
                style: TextStyle(color: Colors.white70, fontSize: 22)),
            Text('${derived.opp}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: () => _changePeriod(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white)),
            Text(periodName(st!['period'], st!['periods']),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            IconButton(
                onPressed: () => _changePeriod(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _toggleClock,
              child: Text(fmtClock(_remaining),
                  style: TextStyle(
                      color: st!['running'] == true
                          ? PgsColors.orange
                          : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900)),
            ),
            IconButton(
                onPressed: _toggleClock,
                icon: Icon(
                    st!['running'] == true
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    color: Colors.white)),
          ]),
        ]),
      ),
      // giocatori in campo
      Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: onCourt.map((n) {
            final p = app.player(n);
            final s = derived.box[n];
            final selected = _sel == n;
            return InkWell(
              onTap: () {
                if (_pend != null) {
                  final k = _pend!;
                  _pend = null;
                  _record(k, n);
                } else {
                  setState(() => _sel = selected ? null : n);
                }
              },
              child: Container(
                width: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected ? PgsColors.orange : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected ? PgsColors.orange : Colors.black12,
                      width: 2),
                ),
                child: Column(children: [
                  Text('#$n',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected ? Colors.white : PgsColors.blue800)),
                  Text(p?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : Colors.black87)),
                  Text('${s?['pts'] ?? 0} pt · ${s?['pf'] ?? 0}F',
                      style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white70 : Colors.black45)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
      // azioni
      Expanded(
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.6,
          children: actions.map((a) {
            final pending = _pend == a.$1;
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    pending ? PgsColors.orange : Colors.white,
                foregroundColor:
                    pending ? Colors.white : PgsColors.blue800,
                padding: EdgeInsets.zero,
              ),
              onPressed: () {
                if (_sel != null) {
                  final n = _sel!;
                  _sel = null;
                  _record(a.$1, n);
                } else {
                  setState(() => _pend = pending ? null : a.$1);
                }
              },
              child: Text(a.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            );
          }).toList(),
        ),
      ),
      // barra inferiore
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(children: [
            _opBtn(1),
            _opBtn(2),
            _opBtn(3),
            const Spacer(),
            IconButton(
                tooltip: 'Cambio',
                onPressed: _sub,
                icon: const Icon(Icons.swap_horiz)),
            IconButton(
                tooltip: 'Annulla',
                onPressed: _undo,
                icon: const Icon(Icons.undo)),
            FilledButton(
                onPressed: _end,
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Termina')),
          ]),
        ),
      ),
    ]);
  }

  Widget _opBtn(int pts) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: OutlinedButton(
          onPressed: () => _opp(pts),
          child: Text('Avv +$pts'),
        ),
      );
}

class _ScoutSetup extends StatefulWidget {
  final AppState app;
  final void Function(String gid, int periodLen, List<String> roster,
      List<String> five, bool announce) onStart;
  const _ScoutSetup({required this.app, required this.onStart});
  @override
  State<_ScoutSetup> createState() => _ScoutSetupState();
}

class _ScoutSetupState extends State<_ScoutSetup> {
  String? _gid;
  int _minutes = 10;
  bool _announce = true;
  List<String> _squad = [];
  List<String> _five = [];

  @override
  void initState() {
    super.initState();
    final app = widget.app;
    final cands = app.games.where((g) => !g.played).toList();
    final def = (app.nextGame() ?? (cands.isNotEmpty ? cands.first : app.games.first));
    _gid = def.id;
    _loadSquad();
  }

  void _loadSquad() {
    final app = widget.app;
    final L = app.lineups[_gid];
    _squad = (L != null && L.convocati.isNotEmpty)
        ? [...L.convocati]
        : app.roster().map((p) => p.num).toList();
    _five = L != null
        ? L.starters.values.where((n) => _squad.contains(n)).take(5).toList()
        : [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final allNums = app.roster().map((p) => p.num).toList();
    final ordered = [..._squad, ...allNums.where((n) => !_squad.contains(n))];

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('🔴', 'Scout live'),
      PgsCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButton<String>(
            value: _gid,
            isExpanded: true,
            items: app.games.map((g) {
              final d = g.dateTime;
              return DropdownMenuItem(
                  value: g.id,
                  child: Text('${d.day} ${mese(d)} · ${g.teams.join(' – ')}',
                      overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (v) => setState(() {
              _gid = v;
              _loadSquad();
            }),
          ),
          Row(children: [
            const Text('Durata quarto: ',
                style: TextStyle(fontWeight: FontWeight.w700)),
            DropdownButton<int>(
              value: _minutes,
              items: const [10, 8, 12, 6]
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                  .toList(),
              onChanged: (v) => setState(() => _minutes = v ?? 10),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
              'Tocca per togliere/rimettere un giocatore. Tocca di nuovo per il quintetto (⭐).',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ordered.map((n) {
              final p = app.player(n);
              final on = _squad.contains(n);
              final s5 = _five.contains(n);
              return InkWell(
                onTap: () => setState(() {
                  if (!_squad.contains(n)) {
                    _squad.add(n);
                  } else if (!_five.contains(n)) {
                    if (_five.length < 5) {
                      _five.add(n);
                    } else {
                      _squad.remove(n);
                    }
                  } else {
                    _five.remove(n);
                    _squad.remove(n);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: s5
                        ? PgsColors.orange
                        : on
                            ? PgsColors.blue
                            : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('#$n ${p?.name ?? ''}${s5 ? ' ⭐' : ''}',
                      style: TextStyle(
                          color: on || s5 ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _announce,
            onChanged: (v) => setState(() => _announce = v ?? true),
            title: const Text('Avvisa la squadra: "🔴 Si gioca!"'),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_five.length != 5) {
                  toast(context,
                      'Scegli il quintetto iniziale: ${_five.length}/5 ⭐',
                      error: true);
                  return;
                }
                widget.onStart(
                    _gid!, _minutes * 60000, _squad, _five, _announce);
              },
              child: const Text('🏀 Palla a due!'),
            ),
          ),
        ]),
      ),
    ]);
  }
}
