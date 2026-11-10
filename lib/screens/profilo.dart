import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});
  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_next.text.length < 4) {
      toast(context, 'La nuova password è troppo corta', error: true);
      return;
    }
    if (_next.text != _confirm.text) {
      toast(context, 'Le password non coincidono', error: true);
      return;
    }
    setState(() => _busy = true);
    final app = context.read<AppState>();
    try {
      await app.api.request('/me/password',
          method: 'POST',
          body: {'current': _current.text, 'next': _next.text});
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) toast(context, 'Password aggiornata ✔');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.user!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('👤', 'Profilo'),
      PgsCard(
        color: PgsColors.blue800,
        child: Row(children: [
          Jersey(u.num ?? '?', name: u.name ?? '', size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${u.isCoach ? 'Coach ' : ''}${u.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  Text('#${u.num}',
                      style: const TextStyle(color: Colors.white70)),
                ]),
          ),
        ]),
      ),
      const SectionTitle('Cambia password'),
      PgsCard(
        child: Column(children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Password attuale', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Nuova password', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Conferma nuova password',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _change,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Aggiorna password'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
              'Cambiando password gli altri dispositivi verranno disconnessi.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
    ]);
  }
}
