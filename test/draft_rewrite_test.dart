import 'package:chivoice/features/recording/draft_rewrite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanFillers removes common spoken fillers', () {
    final result = rewriteDraft(
      '嗯，今天先发版本，然后晚上再复盘',
      action: DraftRewriteAction.cleanFillers,
      languageCode: 'zh-CN',
    );

    expect(result, '今天先发版本，晚上再复盘');
  });

  test('todo rewrite extracts actionable items', () {
    final result = rewriteDraft(
      '请联系晓丽，确认上线时间，发送会议纪要',
      action: DraftRewriteAction.todo,
      languageCode: 'zh-CN',
    );

    expect(result, '- 联系晓丽\n- 确认上线时间\n- 发送会议纪要');
  });
}
