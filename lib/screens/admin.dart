import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../logic.dart';
import '../models.dart';
import '../widgets.dart';

const _phaseOptions = ['Andata', 'Ritorno', 'Coppa/Torneo', 'Amichevole'];

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const PageTitle('⚙️', 'Area admin'),
        FilledButton.icon(
          onPressed: () => _editGame(context, app, null),
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi partita'),
        ),
        const SectionTitle('Calendario'),
        ...app.games.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PgsCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.teams.join(' – '),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                          Text(
                              '${g.dateTime.day} ${mese(g.dateTime)} · ${g.time} · ${g.phase}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ]),
                  ),
                  IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editGame(context, app, g)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      onPressed: () => _deleteGame(context, app, g)),
                ]),
              ),
            )),
        const SectionTitle('Password giocatori'),
        PgsCard(
          child: Column(children: [
            ...app.roster().map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('#${p.num} ${p.name}'),
                  trailing: TextButton(
                    onPressed: () => _resetPw(context, app, p),
                    child: const Text('Reset'),
                  ),
                )),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _resetAllPw(context, app),
                child: const Text('Ripristina tutte le password'),
              ),
            ),
          ]),
        ),
        const SectionTitle('Scout live'),
        PgsCard(
          child: Column(children: [
            const Text(
                'Azzera lo scout live corrente (ricominci da capo la diretta).',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _resetLive(context, app),
                label: const Text('Azzera scout live'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _deleteGame(BuildContext context, AppState app, Game g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la partita?'),
        content: Text('${g.teams.join(' – ')} del ${g.dateTime.day} ${mese(g.dateTime)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.api
          .request('/games/${g.id}', method: 'DELETE', body: {'announce': false});
      app.games.removeWhere((x) => x.id == g.id);
      app.touch();
      if (context.mounted) toast(context, 'Partita eliminata');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _resetPw(BuildContext context, AppState app, Player p) async {
    try {
      await app.api.request('/admin/password-reset',
          method: 'POST', body: {'num': p.num});
      if (context.mounted) toast(context, 'Password di #${p.num} ripristinata');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _resetAllPw(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ripristinare tutte le password?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.api.request('/admin/password-reset',
          method: 'POST', body: {'all': true});
      if (context.mounted) toast(context, 'Tutte le password ripristinate');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  Future<void> _resetLive(BuildContext context, AppState app) async {
    try {
      await app.api.request('/live', method: 'DELETE');
      app.live = null;
      app.touch();
      if (context.mounted) toast(context, 'Scout azzerato 🏀');
    } catch (e) {
      if (context.mounted) toast(context, '$e', error: true);
    }
  }

  void _editGame(BuildContext context, AppState app, Game? game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _GameForm(app: app, game: game),
      ),
    );
  }
}

class _GameForm extends StatefulWidget {
  final AppState app;
  final Game? game;
  const _GameForm({required this.app, this.game});
  @override
  State<_GameForm> createState() => _GameFormState();
}

class _GameFormState extends State<_GameForm> {
  late TextEditingController _opponent;
  late TextEditingController _venue;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _home;
  late String _phase;
  bool _announce = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final g = widget.game;
    _opponent = TextEditingController(text: g?.opponent ?? '');
    _venue = TextEditingController(text: g?.venue ?? '');
    final dt = g?.dateTime ?? DateTime.now();
    _date = DateTime(dt.year, dt.month, dt.day);
    _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    _home = g?.home ?? true;
    _phase = g?.phase ?? 'Andata';
  }

  @override
  void dispose() {
    _opponent.dispose();
    _venue.dispose();
    super.dispose();
  }

  String get _iso {
    final d = _date;
    final t = _time;
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p2(d.month)}-${p2(d.day)}T${p2(t.hour)}:${p2(t.minute)}';
  }

  Future<void> _submit() async {
    if (_opponent.text.trim().isEmpty) {
      toast(context, 'Inserisci l\'avversario', error: true);
      return;
    }
    setState(() => _busy = true);
    final app = widget.app;
    final body = {
      'date': _iso,
      'opponent': _opponent.text.trim(),
      'home': _home,
      'venue': _venue.text.trim(),
      'phase': _phase,
      'announce': _announce,
    };
    try {
      if (widget.game == null) {
        final r = await app.api.request('/games', method: 'POST', body: body);
        app.games.add(Game.fromJson(Map<String, dynamic>.from(r)));
      } else {
        final r = await app.api
            .request('/games/${widget.game!.id}', method: 'PUT', body: body);
        final idx = app.games.indexWhere((x) => x.id == widget.game!.id);
        if (idx >= 0) {
          app.games[idx] = Game.fromJson(Map<String, dynamic>.from(r));
        }
      }
      app.games.sort((a, b) => a.date.compareTo(b.date));
      app.touch();
      if (mounted) {
        Navigator.pop(context);
        toast(context, widget.game == null ? 'Partita aggiunta 📅' : 'Partita aggiornata');
      }
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.game == null ? 'Nuova partita' : 'Modifica partita',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
          controller: _opponent,
          decoration: const InputDecoration(
              labelText: 'Avversario', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _venue,
          decoration: const InputDecoration(
              labelText: 'Campo / palazzetto', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat('d MMM yyyy', 'it').format(_date)),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2026),
                    lastDate: DateTime(2028));
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(_time.format(context)),
              onPressed: () async {
                final t = await showTimePicker(
                    context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('🏠 Casa')),
                ButtonSegment(value: false, label: Text('🚌 Fuori')),
              ],
              selected: {_home},
              onSelectionChanged: (s) => setState(() => _home = s.first),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _phase,
          decoration: const InputDecoration(
              labelText: 'Fase', border: OutlineInputBorder()),
          items: _phaseOptions
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _phase = v ?? 'Andata'),
        ),
        const SizedBox(height: 6),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _announce,
          onChanged: (v) => setState(() => _announce = v ?? false),
          title: const Text('Avvisa la squadra (bacheca + notifica)'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Salva partita'),
          ),
        ),
      ]),
    );
  }
}
