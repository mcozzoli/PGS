import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets.dart';

class SquadraScreen extends StatelessWidget {
  const SquadraScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final roster = app.roster();
    final coach = app.players.where((p) => p.role == 'coach').toList();

    return RefreshIndicator(
      onRefresh: () => app.bootstrap(),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const PageTitle('👥', 'La squadra'),
        const SectionTitle('Roster'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: [
            ...roster.map((p) => _rosterCard(p.num, p.name,
                p.num == app.captain ? 'Capitano' : '#${p.num}')),
            ...coach.map((c) => _rosterCard('C', c.name, 'Allenatore')),
          ],
        ),
      ]),
    );
  }

  Widget _rosterCard(String num, String name, String sub) => PgsCard(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Jersey(num, name: name, size: 56),
          const SizedBox(height: 6),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      );
}
