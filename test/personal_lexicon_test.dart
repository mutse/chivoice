import 'package:chivoice/features/settings/personal_lexicon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applies enabled lexicon entries to chinese and english terms', () {
    final result = applyPersonalLexicon('小丽帮我整理api文档', const [
      PersonalLexiconEntry(id: '1', spokenForm: '小丽', writtenForm: '晓丽'),
      PersonalLexiconEntry(id: '2', spokenForm: 'api', writtenForm: 'API'),
    ]);

    expect(result, '晓丽帮我整理API文档');
  });

  test('ignores disabled lexicon entries', () {
    final result = applyPersonalLexicon('小丽今天会来', const [
      PersonalLexiconEntry(
        id: '1',
        spokenForm: '小丽',
        writtenForm: '晓丽',
        enabled: false,
      ),
    ]);

    expect(result, '小丽今天会来');
  });
}
