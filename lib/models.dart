// Modelli dati dell'app PGS Salgen. Rispecchiano le strutture restituite
// dall'API del portale basketsalgen (vedi functions/api/[[path]].js lato server).

/// Chiavi statistiche di una scheda giocatore, nello stesso ordine del portale.
const List<String> kStatKeys = [
  'min', 'pts', 'p2m', 'p2a', 'p3m', 'p3a', 'ftm', 'fta',
  'oreb', 'dreb', 'reb', 'ast', 'stl', 'blk', 'to', 'pf',
];

const Map<String, String> kStatLabel = {
  'min': 'MIN', 'pts': 'PTS', 'p2m': '2PM', 'p2a': '2PA', 'p3m': '3PM',
  'p3a': '3PA', 'ftm': 'TLM', 'fta': 'TLA', 'oreb': 'RO', 'dreb': 'RD',
  'reb': 'RT', 'ast': 'AST', 'stl': 'PR', 'blk': 'STP', 'to': 'PP', 'pf': 'F',
};

/// Posizioni in campo per il quintetto.
class CourtPos {
  final String key;
  final String label;
  final double x; // percentuale 0-100
  final double y;
  const CourtPos(this.key, this.label, this.x, this.y);
}

const List<CourtPos> kPositions = [
  CourtPos('PG', 'Playmaker', 50, 84),
  CourtPos('SG', 'Guardia', 15, 58),
  CourtPos('SF', 'Ala piccola', 85, 58),
  CourtPos('PF', 'Ala grande', 27, 31),
  CourtPos('C', 'Centro', 70, 25),
];

num _num(dynamic v) => (v is num) ? v : num.tryParse('${v ?? ''}') ?? 0;
int _int(dynamic v) => _num(v).toInt();

class AppUser {
  final String role; // player | coach | admin | fan
  final String? num;
  final String? name;

  AppUser({required this.role, this.num, this.name});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        role: j['role'] ?? 'fan',
        num: j['num']?.toString(),
        name: j['name']?.toString(),
      );

  bool get isFan => role == 'fan';
  bool get isAdmin => role == 'admin';
  bool get isCoach => role == 'coach';
  bool get isPlayer => role == 'player';
  bool get isMember => isPlayer || isCoach;
  bool get isStaff => isAdmin || isCoach;
}

class Player {
  final String num;
  final String name;
  final String role; // player | coach

  Player({required this.num, required this.name, required this.role});

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        num: j['num'].toString(),
        name: j['name']?.toString() ?? '',
        role: j['role']?.toString() ?? 'player',
      );
}

class Game {
  final String id;
  final String date; // ISO: "2026-11-19T18:30"
  final String opponent;
  final bool home;
  final String venue;
  final String phase; // Andata | Ritorno | Coppa/Torneo | Amichevole
  final int? ourScore;
  final int? oppScore;

  Game({
    required this.id,
    required this.date,
    required this.opponent,
    required this.home,
    required this.venue,
    required this.phase,
    this.ourScore,
    this.oppScore,
  });

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'].toString(),
        date: j['date']?.toString() ?? '',
        opponent: j['opponent']?.toString() ?? '',
        home: j['home'] == true,
        venue: j['venue']?.toString() ?? '',
        phase: j['phase']?.toString() ?? 'Andata',
        ourScore: j['ourScore'] == null ? null : _int(j['ourScore']),
        oppScore: j['oppScore'] == null ? null : _int(j['oppScore']),
      );

  bool get played => ourScore != null && oppScore != null;
  bool get official => phase != 'Amichevole';
  DateTime get dateTime => DateTime.tryParse(date) ?? DateTime(2026);
  String get time => date.length >= 16 ? date.substring(11, 16) : '';
  bool get won => played && ourScore! > oppScore!;

  /// [casa, ospite] a seconda che si giochi in casa o fuori.
  List<String> get teams =>
      home ? ['PGS SALGEN', opponent] : [opponent, 'PGS SALGEN'];
}

class Lineup {
  final List<String> convocati;
  final Map<String, String> starters; // POS -> num
  final String? captain;

  Lineup({required this.convocati, required this.starters, this.captain});

  factory Lineup.fromJson(Map<String, dynamic> j) => Lineup(
        convocati:
            (j['convocati'] as List?)?.map((e) => e.toString()).toList() ?? [],
        starters: ((j['starters'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        captain: j['captain']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'convocati': convocati,
        'starters': starters,
        'captain': captain,
      };

  Lineup copy() => Lineup(
        convocati: [...convocati],
        starters: {...starters},
        captain: captain,
      );
}

class StandingsTeam {
  String name;
  bool us;
  int pts, g, w, l, pf, ps;

  StandingsTeam({
    required this.name,
    this.us = false,
    this.pts = 0,
    this.g = 0,
    this.w = 0,
    this.l = 0,
    this.pf = 0,
    this.ps = 0,
  });

  factory StandingsTeam.fromJson(Map<String, dynamic> j) => StandingsTeam(
        name: j['name']?.toString() ?? '',
        us: j['us'] == true,
        pts: _int(j['pts']),
        g: _int(j['g']),
        w: _int(j['w']),
        l: _int(j['l']),
        pf: _int(j['pf']),
        ps: _int(j['ps']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'us': us,
        'pts': pts,
        'g': g,
        'w': w,
        'l': l,
        'pf': pf,
        'ps': ps,
      };

  int get diff => pf - ps;
  StandingsTeam copy() => StandingsTeam.fromJson(toJson());
}

class Standings {
  final List<StandingsTeam> teams;
  final int? updatedAt;
  Standings({required this.teams, this.updatedAt});

  factory Standings.fromJson(Map<String, dynamic> j) => Standings(
        teams: (j['teams'] as List?)
                ?.map((e) => StandingsTeam.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        updatedAt: j['updatedAt'] == null ? null : _int(j['updatedAt']),
      );
}

class BoardInfo {
  final int unread;
  final bool canPost;
  BoardInfo({this.unread = 0, this.canPost = false});
  factory BoardInfo.fromJson(Map<String, dynamic> j) => BoardInfo(
        unread: _int(j['unread']),
        canPost: j['canPost'] == true,
      );
}

class AppConfig {
  final int maxConvocati;
  final String? vapidPublic;
  AppConfig({this.maxConvocati = 15, this.vapidPublic});
  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        maxConvocati: j['maxConvocati'] == null ? 15 : _int(j['maxConvocati']),
        vapidPublic: j['vapidPublic']?.toString(),
      );
}

class Message {
  final String id;
  final String text;
  final String? author;
  final int? ts;
  final int reads;

  Message({
    required this.id,
    required this.text,
    this.author,
    this.ts,
    this.reads = 0,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'].toString(),
        text: j['text']?.toString() ?? '',
        author: j['author']?.toString() ?? j['by']?.toString(),
        ts: j['ts'] == null ? null : _int(j['ts']),
        reads: j['reads'] == null
            ? ((j['readBy'] as List?)?.length ?? 0)
            : _int(j['reads']),
      );
}

/// Evento dello scout live.
class LiveEvent {
  final String id;
  final int p; // periodo
  final int c; // clock ms al momento dell'evento
  final String? num;
  final String k; // chiave azione (2m, 3x, op2, sub, ...)
  final String? out; // per i cambi
  final int? ts;

  LiveEvent({
    required this.id,
    required this.p,
    required this.c,
    required this.k,
    this.num,
    this.out,
    this.ts,
  });

  factory LiveEvent.fromJson(Map<String, dynamic> j) => LiveEvent(
        id: j['id']?.toString() ?? '',
        p: _int(j['p']),
        c: _int(j['c']),
        num: j['num']?.toString(),
        k: j['k']?.toString() ?? '',
        out: j['out']?.toString(),
        ts: j['ts'] == null ? null : _int(j['ts']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'p': p,
        'c': c,
        'num': num,
        'k': k,
        if (out != null) 'out': out,
        'ts': ts,
      };
}

class LiveState {
  final String gid;
  final String status; // live | final
  final int period;
  final int periods;
  final int periodLen;
  final int clockMs;
  final bool running;
  final int? runStartServer;
  final List<String> onCourt;
  final List<String> roster;
  final Map<String, int> played;
  final List<LiveEvent> events;

  LiveState({
    required this.gid,
    required this.status,
    required this.period,
    required this.periods,
    required this.periodLen,
    required this.clockMs,
    required this.running,
    this.runStartServer,
    required this.onCourt,
    required this.roster,
    required this.played,
    required this.events,
  });

  factory LiveState.fromJson(Map<String, dynamic> j) => LiveState(
        gid: j['gid']?.toString() ?? '',
        status: j['status']?.toString() ?? 'live',
        period: j['period'] == null ? 1 : _int(j['period']),
        periods: j['periods'] == null ? 4 : _int(j['periods']),
        periodLen: _int(j['periodLen']),
        clockMs: _int(j['clockMs']),
        running: j['running'] == true,
        runStartServer:
            j['runStartServer'] == null ? null : _int(j['runStartServer']),
        onCourt:
            (j['onCourt'] as List?)?.map((e) => e.toString()).toList() ?? [],
        roster: (j['roster'] as List?)?.map((e) => e.toString()).toList() ?? [],
        played: ((j['played'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), _int(v))),
        events: (j['events'] as List?)
                ?.map((e) => LiveEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  bool get isLive => status == 'live';
  bool get isFinal => status == 'final';
}
