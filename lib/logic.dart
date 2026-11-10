// Funzioni di calcolo pure, tradotte dal frontend del portale (app.js).
import 'models.dart';

const List<String> kMesi = [
  'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU',
  'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC',
];
const List<String> kGiorni = [
  'Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato',
];

String weekday(DateTime d) => kGiorni[d.weekday % 7];
String mese(DateTime d) => kMesi[d.month - 1];

/// Mappa azione scout -> campi statistici incrementati e punti.
class ScoutAction {
  final String label;
  final String feed;
  final List<String> stats;
  final int pts;
  const ScoutAction(this.label, this.feed, this.stats, {this.pts = 0});
}

const Map<String, ScoutAction> kActions = {
  '2m': ScoutAction('2 ✓', 'canestro da 2', ['p2m', 'p2a'], pts: 2),
  '2x': ScoutAction('2 ✗', 'errore da 2', ['p2a']),
  '3m': ScoutAction('3 ✓', 'TRIPLA!', ['p3m', 'p3a'], pts: 3),
  '3x': ScoutAction('3 ✗', 'errore da 3', ['p3a']),
  '1m': ScoutAction('TL ✓', 'tiro libero', ['ftm', 'fta'], pts: 1),
  '1x': ScoutAction('TL ✗', 'libero sbagliato', ['fta']),
  'or': ScoutAction('R.Off', 'rimbalzo offensivo', ['oreb']),
  'dr': ScoutAction('R.Dif', 'rimbalzo difensivo', ['dreb']),
  'as': ScoutAction('Assist', 'assist', ['ast']),
  'st': ScoutAction('Recup.', 'palla recuperata', ['stl']),
  'bk': ScoutAction('Stop.', 'stoppata', ['blk']),
  'to': ScoutAction('Palla p.', 'palla persa', ['to']),
  'pf': ScoutAction('Fallo', 'fallo', ['pf']),
};

/// Totali su una lista di schede statistiche.
Map<String, num> totals(Iterable<Map<String, dynamic>> list) {
  final t = <String, num>{for (final k in kStatKeys) k: 0};
  for (final s in list) {
    for (final k in kStatKeys) {
      t[k] = t[k]! + ((s[k] as num?) ?? 0);
    }
  }
  return t;
}

/// Valutazione (come nel portale).
num valutazione(Map<String, dynamic> s) {
  num n(String k) => (s[k] as num?) ?? 0;
  return n('pts') +
      n('reb') +
      n('ast') +
      n('stl') +
      n('blk') -
      (n('p2a') + n('p3a') - n('p2m') - n('p3m')) -
      (n('fta') - n('ftm')) -
      n('to');
}

int? pct(num made, num att) => att == 0 ? null : (made / att * 100).round();
num r1(num x) => (x * 10).round() / 10;

/// Risultato del calcolo live derivato dagli eventi.
class LiveDerived {
  final Map<String, Map<String, num>> box;
  final int us;
  final int opp;
  final Map<int, int> teamFouls;
  LiveDerived(this.box, this.us, this.opp, this.teamFouls);
}

LiveDerived deriveLive(LiveState st) {
  final box = <String, Map<String, num>>{};
  Map<String, num> zero() => {for (final k in kStatKeys) k: 0};
  int opp = 0;
  final teamFouls = <int, int>{};
  for (final n in st.roster) {
    box[n] = zero();
  }
  for (final e in st.events) {
    if (e.k.startsWith('op')) {
      opp += int.tryParse(e.k.substring(2)) ?? 0;
      continue;
    }
    if (e.k == 'sub' || e.num == null) continue;
    final s = box.putIfAbsent(e.num!, zero);
    final a = kActions[e.k];
    if (a != null) {
      for (final f in a.stats) {
        s[f] = s[f]! + 1;
      }
      if (a.pts > 0) s['pts'] = s['pts']! + a.pts;
    }
    if (e.k == 'pf') teamFouls[e.p] = (teamFouls[e.p] ?? 0) + 1;
  }
  int us = 0;
  box.forEach((n, s) {
    s['reb'] = s['oreb']! + s['dreb']!;
    s['min'] = ((st.played[n] ?? 0) / 6000).round() / 10;
    us += s['pts']!.toInt();
  });
  return LiveDerived(box, us, opp, teamFouls);
}

String periodName(int p, [int n = 4]) =>
    p <= n ? 'Q$p' : 'OT${p - n > 1 ? p - n : ''}';

String fmtClock(int ms) {
  final s = ms <= 0 ? 0 : (ms / 1000).ceil();
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

/// Iniziali di una squadra per il badge (max 3 lettere).
String teamInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final ini = parts.map((w) => w[0]).join();
  return ini.length > 3 ? ini.substring(0, 3) : ini;
}
