import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import 'home.dart';
import 'diretta.dart';
import 'bacheca.dart';
import 'calendario.dart';
import 'risultati.dart';
import 'classifica.dart';
import 'stats.dart';
import 'squadra.dart';
import 'coach.dart';
import 'admin.dart';
import 'scout.dart';
import 'profilo.dart';

/// Voce di navigazione.
class _Route {
  final String key;
  final IconData icon;
  final String label;
  final Widget Function() build;
  const _Route(this.key, this.icon, this.label, this.build);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _route = 'home';

  List<_Route> _routesFor(AppState app) {
    final u = app.user!;
    final all = <_Route>[
      _Route('home', Icons.home_rounded, 'Home', () => const HomeScreen()),
      if (app.liveOn || u.isFan || u.isMember || u.isAdmin)
        _Route('diretta', Icons.sensors_rounded, 'Diretta',
            () => const DirettaScreen()),
      if (!u.isFan)
        _Route('bacheca', Icons.campaign_rounded, 'Bacheca',
            () => const BachecaScreen()),
      _Route('calendario', Icons.calendar_month_rounded, 'Calendario',
          () => const CalendarioScreen()),
      if (!u.isFan)
        _Route('risultati', Icons.emoji_events_rounded, 'Risultati',
            () => const RisultatiScreen()),
      _Route('classifica', Icons.leaderboard_rounded, 'Classifica',
          () => const ClassificaScreen()),
      if (!u.isFan)
        _Route('stats', Icons.bar_chart_rounded, 'Statistiche',
            () => const StatsScreen()),
      if (!u.isFan)
        _Route('squadra', Icons.groups_rounded, 'Squadra',
            () => const SquadraScreen()),
      if (u.isStaff)
        _Route('coach', Icons.assignment_rounded, 'Coach',
            () => const CoachScreen()),
      if (u.isAdmin)
        _Route('admin', Icons.settings_rounded, 'Admin',
            () => const AdminScreen()),
      if (u.isAdmin)
        _Route('scout', Icons.sports_basketball_rounded, 'Scout',
            () => const ScoutScreen()),
      if (u.isMember)
        _Route('profilo', Icons.person_rounded, 'Profilo',
            () => const ProfiloScreen()),
    ];
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final routes = _routesFor(app);
    final current =
        routes.firstWhere((r) => r.key == _route, orElse: () => routes.first);

    // barra inferiore: fino a 4 voci + "Altro"
    final primary = routes.take(4).toList();
    final hasMore = routes.length > 4;
    final navItems = [
      ...primary,
      if (hasMore)
        const _Route('__more', Icons.more_horiz_rounded, 'Altro', _nullBuild),
    ];
    int selectedIndex = primary.indexWhere((r) => r.key == current.key);
    if (selectedIndex < 0) selectedIndex = hasMore ? navItems.length - 1 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(Config.logoUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.sports_basketball)),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('PGS SALGEN',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('ROMA · 2026/27',
                  style: TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ]),
        actions: [
          _userChip(app),
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => app.logout(),
          ),
        ],
      ),
      body: SafeArea(child: current.build()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          final r = navItems[i];
          if (r.key == '__more') {
            _openMore(context, routes.skip(4).toList());
          } else {
            setState(() => _route = r.key);
          }
        },
        destinations: navItems
            .map((r) => NavigationDestination(
                  icon: r.key == 'bacheca' && app.board.unread > 0
                      ? Badge(
                          label: Text('${app.board.unread}'),
                          child: Icon(r.icon))
                      : Icon(r.icon),
                  label: r.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _userChip(AppState app) {
    final u = app.user!;
    final who = u.isFan
        ? '📣 Tifoso'
        : u.isAdmin
            ? 'Admin'
            : '${u.isCoach ? 'Coach ' : ''}${u.name} #${u.num}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(who,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  void _openMore(BuildContext context, List<_Route> rest) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rest
              .map((r) => ListTile(
                    leading: Icon(r.icon, color: PgsColors.blue800),
                    title: Text(r.label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _route = r.key);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

Widget _nullBuild() => const SizedBox.shrink();
