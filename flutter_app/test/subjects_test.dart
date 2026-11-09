import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reader_hd/core/quran.dart';
import 'package:quran_reader_hd/data/subjects.dart';

void main() {
  test('every ayah is in exactly one section, in order, never sharing a colour with its neighbours', () {
    expect(subjectCount, 556);
    final first = subjectOf(const AyahKey(1, 1))!;
    expect((first.index, first.from, first.to), (0, const AyahKey(1, 1), const AyahKey(1, 7)));
    // Al-Baqara opens with the people of taqwa and the disbelievers (2:1–7), then the hypocrites (2:8–20).
    expect(subjectOf(const AyahKey(2, 7))!.to, const AyahKey(2, 7));
    final hypocrites = subjectOf(const AyahKey(2, 8))!;
    expect((hypocrites.from, hypocrites.to), (const AyahKey(2, 8), const AyahKey(2, 20)));
    expect(subjectOf(const AyahKey(2, 15)), hypocrites);
    final last = subjectOf(const AyahKey(114, 6))!;
    expect((last.index, last.from), (555, const AyahKey(114, 1)));
    // Section by section, each starts after the previous one ends, in the same surah or the next one's first ayah.
    var previous = first;
    for (var i = 1; i < subjectCount; i++) {
      var s = subjectOf(AyahKey(previous.to.sura, previous.to.ayah + 1))!;
      // Past the surah's last ayah: the next surah's first section.
      if (s == previous) s = subjectOf(AyahKey(previous.to.sura + 1, 1))!;
      expect(s.index, i);
      expect(s.color, isNot(previous.color));
      previous = s;
    }
  });
}
