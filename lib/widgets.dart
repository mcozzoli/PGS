import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'logic.dart';
import 'models.dart';
import 'theme.dart';

/// Intestazione di sezione (— titolo —).
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
        child: Row(children: [
          const Expanded(child: Divider(thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: PgsColors.blue800,
                    letterSpacing: 0.5)),
          ),
          const Expanded(child: Divider(thickness: 1.5)),
        ]),
      );
}

/// Titolo pagina con emoji.
class PageTitle extends StatelessWidget {
  final String emoji;
  final String text;
  const PageTitle(this.emoji, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: PgsColors.blue800)),
        ]),
      );
}

/// Card bianca standard con padding.
class PgsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  const PgsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

/// Riquadro statistica (numero grande + etichetta).
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool hot;
  const StatTile(this.value, this.label, {super.key, this.hot = false});
  @override
  Widget build(BuildContext context) => PgsCard(
        color: hot ? PgsColors.orange.withValues(alpha: 0.12) : null,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: hot ? PgsColors.orange : PgsColors.blue800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
        ]),
      );
}

/// Canotta con numero e nome (equivalente del jersey SVG).
class Jersey extends StatelessWidget {
  final String number;
  final String name;
  final double size;
  const Jersey(this.number, {super.key, this.name = '', this.size = 64});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(
        painter: _JerseyPainter(number, name),
      ),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  final String number;
  final String name;
  _JerseyPainter(this.number, this.name);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Paint()..color = PgsColors.blue;
    final path = Path();
    // forma canotta semplificata
    path.moveTo(w * 0.28, h * 0.04);
    path.quadraticBezierTo(w * 0.38, h * 0.18, w * 0.5, h * 0.18);
    path.quadraticBezierTo(w * 0.62, h * 0.18, w * 0.72, h * 0.04);
    path.lineTo(w * 0.90, h * 0.09);
    path.quadraticBezierTo(w * 0.85, h * 0.30, w * 0.93, h * 0.42);
    path.lineTo(w * 0.93, h * 0.97);
    path.lineTo(w * 0.07, h * 0.97);
    path.lineTo(w * 0.07, h * 0.42);
    path.quadraticBezierTo(w * 0.15, h * 0.30, w * 0.10, h * 0.09);
    path.close();
    canvas.drawPath(path, body);
    // fascia arancione
    canvas.drawRect(
        Rect.fromLTWH(w * 0.07, h * 0.88, w * 0.86, h * 0.05),
        Paint()..color = PgsColors.orange);

    void text(String s, double cy, double fs, FontWeight fw) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                color: Colors.white, fontSize: fs, fontWeight: fw)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: w);
      tp.paint(canvas, Offset((w - tp.width) / 2, cy - tp.height / 2));
    }

    if (name.isNotEmpty) {
      final nm = name.toUpperCase();
      text(nm.length > 10 ? nm.substring(0, 10) : nm, h * 0.34,
          nm.length > 8 ? w * 0.11 : w * 0.14, FontWeight.w700);
      text(number, h * 0.68, w * 0.42, FontWeight.w900);
    } else {
      text(number, h * 0.62, w * 0.48, FontWeight.w900);
    }
  }

  @override
  bool shouldRepaint(covariant _JerseyPainter old) =>
      old.number != number || old.name != name;
}

/// Badge tondo di una squadra (logo per PGS, iniziali per le altre).
class TeamBadge extends StatelessWidget {
  final String team;
  final double size;
  const TeamBadge(this.team, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final isUs = team == 'PGS SALGEN';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isUs ? Colors.white : PgsColors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: PgsColors.blue800.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: isUs
          ? Image.network(Config.logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Text('PGS', style: TextStyle(fontWeight: FontWeight.w900)))
          : Text(teamInitials(team),
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.3)),
    );
  }
}

/// Pillola colorata (stati: casa/trasferta, vinta/persa, ecc.).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = PgsColors.blue});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

/// Banner di stato con emoji (convocazioni, bacheca, live…).
class StatusBanner extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  const StatusBanner(this.emoji, this.text,
      {super.key, this.color = PgsColors.blue, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: color.withValues(alpha: 1)))),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.black38),
          ]),
        ),
      );
}

/// Card di una partita (prossima / ultimo risultato).
class MatchCard extends StatelessWidget {
  final Game game;
  final String title;
  const MatchCard(this.game, this.title, {super.key});
  @override
  Widget build(BuildContext context) {
    final d = game.dateTime;
    final t = game.teams;
    return PgsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(game.home ? '🏠 Casa' : '🚌 Trasferta',
              color: game.home ? PgsColors.blue : PgsColors.orange),
        ]),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: PgsColors.blue800)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _teamCol(t[0])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
                game.played
                    ? '${game.home ? game.ourScore : game.oppScore} - ${game.home ? game.oppScore : game.ourScore}'
                    : 'VS',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: PgsColors.orange)),
          ),
          Expanded(child: _teamCol(t[1])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('📆 '),
          Expanded(
              child: Text(
                  '${weekday(d)} ${d.day} ${mese(d)} · ore ${game.time}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 2),
        InkWell(
          onTap: () => launchUrl(
              Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(game.venue)}'),
              mode: LaunchMode.externalApplication),
          child: Row(children: [
            const Text('📍 '),
            Expanded(
                child: Text(game.venue,
                    style: const TextStyle(
                        color: PgsColors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        if (!game.played) _Countdown(game),
      ]),
    );
  }

  Widget _teamCol(String name) => Column(children: [
        TeamBadge(name),
        const SizedBox(height: 4),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ]);
}

class _Countdown extends StatefulWidget {
  final Game game;
  const _Countdown(this.game);
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Stream<int> _tick;
  @override
  void initState() {
    super.initState();
    _tick = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _tick,
      builder: (context, _) {
        final diff = widget.game.dateTime.difference(DateTime.now());
        int s = diff.inSeconds;
        if (s < 0) s = 0;
        final parts = {
          'giorni': s ~/ 86400,
          'ore': (s % 86400) ~/ 3600,
          'min': (s % 3600) ~/ 60,
          'sec': s % 60,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: s == 0
              ? const Center(
                  child: Text('🏀 si gioca!',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: PgsColors.orange)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: parts.entries
                      .map((e) => Column(children: [
                            Text(e.value.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: PgsColors.blue800)),
                            Text(e.key,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.black54)),
                          ]))
                      .toList(),
                ),
        );
      },
    );
  }
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : PgsColors.blue800,
    ));
}
