import 'package:flutter/material.dart';

enum DraftRewriteAction { cleanFillers, formal, concise, paragraph, todo }

class DraftRewriteOption {
  const DraftRewriteOption({
    required this.action,
    required this.label,
    required this.description,
    required this.icon,
  });

  final DraftRewriteAction action;
  final String label;
  final String description;
  final IconData icon;
}

const draftRewriteOptions = <DraftRewriteOption>[
  DraftRewriteOption(
    action: DraftRewriteAction.cleanFillers,
    label: '去口语',
    description: '去掉嗯啊然后等赘词',
    icon: Icons.cleaning_services_outlined,
  ),
  DraftRewriteOption(
    action: DraftRewriteAction.formal,
    label: '更正式',
    description: '把表达整理得更像手打',
    icon: Icons.draw_outlined,
  ),
  DraftRewriteOption(
    action: DraftRewriteAction.concise,
    label: '压缩一句',
    description: '保留重点，适合直接发送',
    icon: Icons.short_text,
  ),
  DraftRewriteOption(
    action: DraftRewriteAction.paragraph,
    label: '分段',
    description: '适合长语音整理成文',
    icon: Icons.segment_outlined,
  ),
  DraftRewriteOption(
    action: DraftRewriteAction.todo,
    label: '提炼待办',
    description: '把行动项单独列出来',
    icon: Icons.checklist_rtl_outlined,
  ),
];

String rewriteDraft(
  String value, {
  required DraftRewriteAction action,
  required String languageCode,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final usesCjk = _usesCjkFormatting(languageCode, trimmed);
  return switch (action) {
    DraftRewriteAction.cleanFillers => _removeFillers(trimmed, usesCjk),
    DraftRewriteAction.formal => _rewriteFormal(trimmed, usesCjk),
    DraftRewriteAction.concise => _rewriteConcise(trimmed, usesCjk),
    DraftRewriteAction.paragraph => _rewriteParagraphs(trimmed, usesCjk),
    DraftRewriteAction.todo => _extractTodoList(trimmed, usesCjk),
  };
}

String _removeFillers(String value, bool usesCjk) {
  var normalized = value;
  if (usesCjk) {
    normalized = normalized
        .replaceFirst(RegExp(r'^((嗯|啊|呃|额|那个|就是|然后|其实)[，,\s]*)+'), '')
        .replaceAllMapped(
          RegExp(r'([，。！？；\n])\s*(嗯|啊|呃|额|那个|就是|然后|其实)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'\b(嗯|啊|呃|额)\b'), '');
  } else {
    normalized = normalized.replaceAll(
      RegExp(r'\b(um|uh|you know|like|actually)\b', caseSensitive: false),
      '',
    );
  }

  normalized = normalized
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'([，。！？；,.!?])\1+'), r'$1')
      .trim();
  return normalized.isEmpty ? value.trim() : normalized;
}

String _rewriteFormal(String value, bool usesCjk) {
  var normalized = _removeFillers(value, usesCjk);
  final replacements = usesCjk
      ? <MapEntry<String, String>>[
          const MapEntry('想问一下', '请问'),
          const MapEntry('我想问一下', '请问'),
          const MapEntry('麻烦你', '烦请'),
          const MapEntry('帮我', '请帮我'),
          const MapEntry('看一下', '查看一下'),
          const MapEntry('说一下', '说明一下'),
          const MapEntry('搞一下', '处理一下'),
          const MapEntry('回头', '稍后'),
          const MapEntry('发我', '发送给我'),
        ]
      : <MapEntry<String, String>>[
          const MapEntry('can you', 'could you please'),
          const MapEntry('send me', 'please send me'),
          const MapEntry('check this', 'please review this'),
        ];

  for (final replacement in replacements) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }

  return _finalizeSentence(normalized, usesCjk);
}

String _rewriteConcise(String value, bool usesCjk) {
  final clauses = _splitClauses(_removeFillers(value, usesCjk));
  if (clauses.isEmpty) {
    return _finalizeSentence(value.trim(), usesCjk);
  }

  final deduped = <String>[];
  for (final clause in clauses) {
    if (deduped.isEmpty || deduped.last != clause) {
      deduped.add(clause);
    }
  }

  final takeCount = deduped.length > 2 ? 2 : deduped.length;
  final connector = usesCjk ? '，' : ', ';
  final joined = deduped.take(takeCount).join(connector);
  return _finalizeSentence(joined, usesCjk);
}

String _rewriteParagraphs(String value, bool usesCjk) {
  final clauses = _splitClauses(value);
  if (clauses.length <= 2) {
    return _finalizeSentence(_removeFillers(value, usesCjk), usesCjk);
  }

  final paragraphs = <String>[];
  for (var index = 0; index < clauses.length; index += 2) {
    final slice = clauses.skip(index).take(2).toList();
    paragraphs.add(
      _finalizeSentence(slice.join(usesCjk ? '，' : ', '), usesCjk),
    );
  }
  return paragraphs.join('\n\n');
}

String _extractTodoList(String value, bool usesCjk) {
  final clauses = _splitClauses(_removeFillers(value, usesCjk));
  if (clauses.isEmpty) {
    return value.trim();
  }

  final actionable = clauses.where(_looksActionable).toList();
  final source = actionable.isEmpty ? clauses : actionable;
  return source.map((clause) => '- ${_stripLeadingVerb(clause)}').join('\n');
}

List<String> _splitClauses(String value) {
  return value
      .split(RegExp(r'[。！？；，,.!?\n]+'))
      .map((clause) => clause.trim())
      .where((clause) => clause.isNotEmpty)
      .toList();
}

String _finalizeSentence(String value, bool usesCjk) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  if (RegExp(r'[。！？.!?]$').hasMatch(trimmed)) {
    return trimmed;
  }
  return '$trimmed${usesCjk ? '。' : '.'}';
}

bool _looksActionable(String value) {
  return RegExp(
    r'(请|需要|记得|安排|确认|提交|联系|发送|更新|准备|跟进|call|send|check|review|follow up)',
    caseSensitive: false,
  ).hasMatch(value);
}

String _stripLeadingVerb(String value) {
  return value
      .replaceFirst(RegExp(r'^(请|麻烦|需要|记得)\s*'), '')
      .replaceFirst(RegExp(r'^(please)\s+', caseSensitive: false), '')
      .trim();
}

bool _usesCjkFormatting(String languageCode, String value) {
  return languageCode.startsWith('zh') ||
      languageCode.startsWith('ja') ||
      RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]').hasMatch(value);
}
