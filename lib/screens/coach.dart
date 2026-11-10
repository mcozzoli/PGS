import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../widgets.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  String? _gid;
  int _step = 0;
  late Lineup _draft;
  bool _busy = false;
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final notPlayed = app.games.where((g) => !g.played).toList();
    final list = notPlayed.isNotEmpty ? notPlayed : app.games;
    if (list.isEmpty) {
      return const Center(child: Text('Nessuna partita disponibile.'));
    }
    final gid = (_gid != null && list.any((g) => g.id == _gid))
        ? _gid!
        : (app.nextGame() ?? list.first).id;
    if (!_init || _gid != gid) {
      _gid = gid;
      _draft = (app.lineups[gid] ?? Lineup(convocati: [], starters: {})).copy();
      if (app.lineups[gid] == null &&
          app.captain != null &&
          _draft.convocati.contains(app.captain)) {
        _draft = Lineup(
            convocati: _draft.convocati,
            starters: _draft.starters,
            captain: app.captain);
      }
      _init = true;
    }
    final max = app.config.maxConvocati;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('📋', 'Panchina del coach'),
      PgsCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButton<String>(
          value: gid,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: list.map((g) {
            final d = g.dateTime;
            return DropdownMenuItem(
                value: g.id,
                child: Text(
                    '${d.day} ${mese(d)} · ${g.teams.join(' – ')}${app.lineups[g.id] != null ? ' ✔' : ''}',
                    overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) => setState(() {
            _gid = v;
            _init = false;
          }),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('1·Convocati')),
          ButtonSegment(value: 1, label: Text('2·Quintetto')),
          ButtonSegment(value: 2, label: Text('3·Capitano')),
        ],
        selected: {_step},
        onSelectionChanged: (s) => setState(() => _step = s.first),
      ),
      const SizedBox(height: 12),
      if (_step == 0) _convocati(app, max),
      if (_step == 1) _quintetto(app),
      if (_step == 2) _capitano(app),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : () => _save(app),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('💾 Salva e pubblica'),
        ),
      ),
    ]);
  }

  Widget _convocati(AppState app, int max) {
    return PgsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Convocati: ${_draft.convocati.length}/$max',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: app.roster().map((p) {
            final on = _draft.convocati.contains(p.num);
            return FilterChip(
              label: Text('#${p.num} ${p.name}'),
              selected: on,
              onSelected: (v) => setState(() {
                if (v) {
                  if (_draft.convocati.length < max) {
                    _draft.convocati.add(p.num);
                  } else {
                    toast(context, 'Massimo $max convocati', error: true);
                  }
                } else {
                  _draft.convocati.remove(p.num);
                  _draft.starters.removeWhere((k, val) => val == p.num);
                  if (_draft.captain == p.num) {
                    _draft = Lineup(
                        convocati: _draft.convocati,
                        starters: _draft.starters,
                        captain: null);
                  }
                }
              }),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _quintetto(AppState app) {
    final conv = _draft.convocati;
    return PgsCard(
      child: Column(children: [
        const Text('Assegna un convocato a ogni ruolo del quintetto.',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...kPositions.map((pos) {
          final current = _draft.starters[pos.key];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 110,
                child: Text(pos.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: DropdownButton<String?>(
                  value: current,
                  isExpanded: true,
                  hint: const Text('—'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('—')),
                    ...conv.map((num) {
                      final p = app.player(num);
                      return DropdownMenuItem<String?>(
                          value: num, child: Text('#$num ${p?.name ?? ''}'));
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    // rimuovi il giocatore da altri ruoli
                    _draft.starters.removeWhere((k, val) => val == v);
                    if (v == null) {
                      _draft.starters.remove(pos.key);
                    } else {
                      _draft.starters[pos.key] = v;
                    }
                  }),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Text('Quintetto: ${_draft.starters.length}/5',
            style: const TextStyle(color: Colors.black54)),
      ]),
    );
  }

  Widget _capitano(AppState app) {
    return PgsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Capitano della partita',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _draft.convocati.map((num) {
            final p = app.player(num);
            final on = _draft.captain == num;
            return ChoiceChip(
              label: Text('Ⓒ #$num ${p?.name ?? ''}'),
              selected: on,
              onSelected: (_) => setState(() => _draft = Lineup(
                  convocati: _draft.convocati,
                  starters: _draft.starters,
                  captain: on ? null : num)),
            );
          }).toList(),
        ),
        if (_draft.convocati.isEmpty)
          const Text('Scegli prima i convocati.',
              style: TextStyle(color: Colors.black54)),
      ]),
    );
  }

  Future<void> _save(AppState app) async {
    setState(() => _busy = true);
    try {
      final r = await app.api.request('/games/$_gid/lineup',
          method: 'PUT', body: _draft.toJson());
      app.lineups[_gid!] = Lineup.fromJson(Map<String, dynamic>.from(r));
      app.touch();
      if (mounted) {
        toast(context,
            'Formazione salvata: ${_draft.convocati.length} convocati, quintetto ${_draft.starters.length}/5 🏀');
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
