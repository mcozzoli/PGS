import 'package:flutter_test/flutter_test.dart';
import 'package:pgs/logic.dart';
import 'package:pgs/models.dart';

void main() {
  test('periodName gestisce quarti e overtime', () {
    expect(periodName(1), 'Q1');
    expect(periodName(4), 'Q4');
    expect(periodName(5), 'OT');
    expect(periodName(6), 'OT2');
  });

  test('fmtClock formatta mm:ss', () {
    expect(fmtClock(600000), '10:00');
    expect(fmtClock(65000), '01:05');
    expect(fmtClock(-100), '00:00');
  });

  test('deriveLive conta punti e falli', () {
    final st = LiveState.fromJson({
      'gid': 'g1',
      'status': 'live',
      'period': 1,
      'periods': 4,
      'periodLen': 600000,
      'clockMs': 600000,
      'running': false,
      'onCourt': ['7'],
      'roster': ['7', '10'],
      'played': {'7': 60000},
      'events': [
        {'id': 'a', 'p': 1, 'c': 500000, 'num': '7', 'k': '3m'},
        {'id': 'b', 'p': 1, 'c': 400000, 'num': '7', 'k': '2m'},
        {'id': 'c', 'p': 1, 'c': 300000, 'num': null, 'k': 'op2'},
        {'id': 'd', 'p': 1, 'c': 200000, 'num': '7', 'k': 'pf'},
      ],
    });
    final d = deriveLive(st);
    expect(d.us, 5);
    expect(d.opp, 2);
    expect(d.teamFouls[1], 1);
    expect(d.box['7']!['pts'], 5);
  });
}
