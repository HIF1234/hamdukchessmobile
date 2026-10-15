import 'package:flutter_test/flutter_test.dart';
import 'package:hamduk_chess/board/move_announcer.dart';

void main() {
  test('plain moves say the piece and destination', () {
    expect(announceSan('e4'), 'Pawn to e4');
    expect(announceSan('Nf3'), 'Knight to f3');
  });

  test('captures say "takes"', () {
    expect(announceSan('Nxe5'), 'Knight takes e5');
    expect(announceSan('exd5'), 'Pawn takes d5');
  });

  test('check and checkmate are appended', () {
    expect(announceSan('Nxe5+'), 'Knight takes e5, check');
    expect(announceSan('Qh7#'), 'Queen to h7, checkmate');
  });

  test('castling', () {
    expect(announceSan('O-O'), 'Castles kingside');
    expect(announceSan('O-O-O+'), 'Castles queenside, check');
  });

  test('promotion', () {
    expect(announceSan('e8=Q'), 'Pawn to e8, promoting to Queen');
    expect(announceSan('exd1=N+'), 'Pawn takes d1, promoting to Knight, check');
  });
}
