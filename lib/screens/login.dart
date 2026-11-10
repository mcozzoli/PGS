import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../config.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cognome = TextEditingController();
  final _numero = TextEditingController();
  final _password = TextEditingController();
  bool _admin = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cognome.dispose();
    _numero.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PgsColors.blue800, PgsColors.blue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(Config.logoUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                  Icons.sports_basketball,
                                  size: 90,
                                  color: PgsColors.orange)),
                        ),
                        const SizedBox(height: 10),
                        const Text('PGS SALGEN',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: PgsColors.blue800)),
                        const Text('FORZA SALGEN!',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: PgsColors.orange)),
                        const SizedBox(height: 18),
                        Text(_admin ? 'Area admin ⚙️' : 'Entra in campo 🏀',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            _admin
                                ? 'Riservato a chi carica i referti.'
                                : 'Inserisci cognome, numero di maglia e password della squadra.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        if (!_admin) ...[
                          TextField(
                            controller: _cognome,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Cognome',
                                hintText: 'es. Rossi',
                                border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _numero,
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'Numero di maglia',
                                hintText: 'es. 23',
                                counterText: '',
                                border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                          controller: _password,
                          obscureText: true,
                          onSubmitted: (_) => _submit(app),
                          decoration: InputDecoration(
                              labelText: _admin
                                  ? 'Password admin'
                                  : 'Password squadra',
                              border: const OutlineInputBorder()),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : () => _submit(app),
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Entra'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _admin = !_admin;
                                    _error = null;
                                  }),
                          child: Text(_admin
                              ? 'Sono un giocatore'
                              : 'Accesso admin'),
                        ),
                        const Divider(height: 24),
                        const Text('Non sei della squadra?',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: PgsColors.blue),
                            onPressed: _busy
                                ? null
                                : () => _run(() => app.loginFan()),
                            child: const Text('📣 Sono un tifoso'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                            'Partite in programma e diretta live, senza password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(AppState app) {
    if (_admin) {
      _run(() => app.loginAdmin(_password.text));
    } else {
      _run(() =>
          app.loginPlayer(_cognome.text, _numero.text, _password.text));
    }
  }
}
