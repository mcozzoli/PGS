import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_state.dart';
import 'theme.dart';
import 'screens/login.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const PgsApp(),
    ),
  );
}

class PgsApp extends StatelessWidget {
  const PgsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PGS Salgen',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.booting) {
      return const Scaffold(
        backgroundColor: PgsColors.blue800,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return app.loggedIn ? const AppShell() : const LoginScreen();
  }
}
