import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'widgets_bridge.dart';

/// Stato globale dell'app (equivalente dell'oggetto `S` del portale).
class AppState extends ChangeNotifier {
  final Api api = Api();
  static const _tokenKey = 'salgen_token';

  bool booting = true;
  String? _token;

  AppUser? user;
  List<Player> players = [];
  List<Game> games = [];
  Map<String, Lineup> lineups = {};
  String? captain;
  AppConfig config = AppConfig();
  BoardInfo board = BoardInfo();
  Map<String, Map<String, Map<String, dynamic>>> stats = {}; // gid -> num -> stat
  Map<String, List<dynamic>> docs = {};
  Standings standings = Standings(teams: []);

  LiveState? live;
  int liveOffset = 0; // serverNow - localNow (ms)

  bool get loggedIn => user != null;

  // ---- avvio ----
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    api.token = _token;
    if (_token != null) {
      try {
        await bootstrap();
      } on SessionExpired {
        await _clearToken();
      } catch (_) {
        // offline o errore: resta alla login
        await _clearToken();
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> _saveToken(String t) async {
    _token = t;
    api.token = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, t);
  }

  Future<void> _clearToken() async {
    _token = null;
    api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---- auth ----
  Future<void> loginFan() => _login({'fan': true});

  Future<void> loginAdmin(String password) =>
      _login({'admin': true, 'password': password});

  Future<void> loginPlayer(String cognome, String numero, String password) =>
      _login({'cognome': cognome, 'numero': numero, 'password': password});

  Future<void> _login(Map<String, dynamic> body) async {
    final r = await api.request('/login', method: 'POST', body: body);
    await _saveToken(r['token'].toString());
    await bootstrap();
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearToken();
    user = null;
    live = null;
    notifyListeners();
  }

  // ---- bootstrap ----
  Future<void> bootstrap() async {
    final b = await api.getMap('/bootstrap');
    user = AppUser.fromJson(Map<String, dynamic>.from(b['user'] ?? {}));

    players = (b['players'] as List?)
            ?.map((e) => Player.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    games = (b['games'] as List?)
            ?.map((e) => Game.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    games.sort((a, b) => a.date.compareTo(b.date));
    lineups = ((b['lineups'] as Map?) ?? {}).map(
      (k, v) => MapEntry(k.toString(), Lineup.fromJson(Map<String, dynamic>.from(v))),
    );
    captain = b['captain']?.toString();
    config = AppConfig.fromJson(Map<String, dynamic>.from(b['config'] ?? {}));
    board = BoardInfo.fromJson(Map<String, dynamic>.from(b['board'] ?? {}));
    standings =
        Standings.fromJson(Map<String, dynamic>.from(b['standings'] ?? {}));
    docs = ((b['docs'] as Map?) ?? {})
        .map((k, v) => MapEntry(k.toString(), (v as List?) ?? []));

    if (!user!.isFan) {
      try {
        final st = await api.getMap('/stats');
        stats = st.map((gid, m) => MapEntry(
              gid,
              (m as Map).map((pn, s) => MapEntry(
                    pn.toString(),
                    Map<String, dynamic>.from(s),
                  )),
            ));
      } catch (_) {
        stats = {};
      }
    } else {
      stats = {};
    }
    await refreshLive();
    syncHomeWidget(this);
  }

  Future<void> refreshStats() async {
    if (user == null || user!.isFan) return;
    final st = await api.getMap('/stats');
    stats = st.map((gid, m) => MapEntry(
          gid,
          (m as Map).map(
              (pn, s) => MapEntry(pn.toString(), Map<String, dynamic>.from(s))),
        ));
    notifyListeners();
  }

  // ---- live ----
  Future<void> refreshLive() async {
    try {
      final r = await api.getMap('/live');
      final l = r['live'];
      live = (l == null) ? null : LiveState.fromJson(Map<String, dynamic>.from(l));
      final serverNow = (r['serverNow'] as num?)?.toInt();
      if (serverNow != null) {
        liveOffset = serverNow - DateTime.now().millisecondsSinceEpoch;
      }
    } catch (_) {
      // ignora: manteniamo lo stato precedente
    }
  }

  bool get liveOn => live != null && live!.status == 'live';

  // ---- helper dati ----
  Player? player(String? num) {
    if (num == null) return null;
    for (final p in players) {
      if (p.num == num) return p;
    }
    return null;
  }

  List<Player> roster() => players.where((p) => p.role == 'player').toList();

  Game? nextGame() {
    final now = DateTime.now().millisecondsSinceEpoch - 3 * 3600 * 1000;
    for (final g in games) {
      if (!g.played && g.dateTime.millisecondsSinceEpoch >= now) return g;
    }
    for (final g in games) {
      if (!g.played) return g;
    }
    return null;
  }

  /// Partite con statistiche (ufficiali) per un giocatore.
  List<MapEntry<Game, Map<String, dynamic>>> playerLines(String num) {
    final out = <MapEntry<Game, Map<String, dynamic>>>[];
    for (final g in games) {
      if (!g.official) continue;
      final s = stats[g.id]?[num];
      if (s != null) out.add(MapEntry(g, s));
    }
    return out;
  }

  /// Convocazione del giocatore corrente per una partita.
  ({bool convocato, String? starter, bool captain})? myLineup(String gid) {
    final L = lineups[gid];
    if (L == null || user?.num == null) return null;
    String? pos;
    L.starters.forEach((k, v) {
      if (v == user!.num) pos = k;
    });
    return (
      convocato: L.convocati.contains(user!.num),
      starter: pos,
      captain: L.captain == user!.num,
    );
  }

  void touch() => notifyListeners();
}
