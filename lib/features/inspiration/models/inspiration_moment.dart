import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/app_database.dart';

enum InspirationMode { quick, expanded }

enum InspirationCategory { ingenuity, reflection, mood, chronicle, excerpt }

class InspirationVariant {
  const InspirationVariant({
    required this.mode,
    required this.category,
    required this.index,
  });

  final InspirationMode mode;
  final InspirationCategory category;
  final int index;
}

class InspirationTone {
  const InspirationTone({
    required this.tint,
    required this.accent,
    required this.gradient,
    required this.wash,
    required this.opacity,
    required this.radius,
    required this.elevation,
  });

  final Color tint;
  final Color accent;
  final List<Color> gradient;
  final Color wash;
  final double opacity;
  final double radius;
  final double elevation;
}

class InspirationMoment {
  const InspirationMoment({
    required this.intent,
    required this.id,
    required this.stableKey,
    required this.badge,
    required this.title,
    required this.body,
    required this.tags,
    required this.category,
    required this.variant,
    required this.tone,
    required this.createdAt,
    this.localImagePaths = const [],
  });

  final FlowIntent intent;
  final int id;
  final String stableKey;
  final String badge;
  final String title;
  final String body;
  final List<String> tags;
  final InspirationCategory category;
  final InspirationVariant variant;
  final InspirationTone tone;
  final DateTime createdAt;
  final List<String> localImagePaths;

  bool get hasImage => localImagePaths.isNotEmpty;
  bool get isExpanded => title.trim().isNotEmpty && body.trim().isNotEmpty;

  factory InspirationMoment.fromFlowIntent(FlowIntent intent) {
    const badges = ['念', '拾', '笺', '息', '光', '观'];
    final tags = _parseTags(intent.tags);
    final category = _categoryFromTags(tags);
    final imagePaths = _parseAttachments(intent.attachments);
    final rawTitle = intent.title.trim();
    final rawBody = (intent.note?.trim().isNotEmpty == true)
        ? intent.note!.trim()
        : intent.rawInput.trim();
    final mode =
        rawTitle.isNotEmpty && rawBody.isNotEmpty && rawTitle != rawBody
        ? InspirationMode.expanded
        : InspirationMode.quick;

    final stableKey = intent.serverId ?? '${intent.id}';
    final seed = _stableHash(
      '$stableKey-${intent.createdAt.millisecondsSinceEpoch}',
    );
    final variantIndex = seed % 3;

    return InspirationMoment(
      intent: intent,
      id: intent.id,
      stableKey: stableKey,
      badge: badges[seed % badges.length],
      title: mode == InspirationMode.quick ? '' : rawTitle,
      body: rawBody.isNotEmpty ? rawBody : rawTitle,
      tags: tags.isEmpty ? [_categoryLabel(category)] : tags,
      category: category,
      variant: InspirationVariant(
        mode: mode,
        category: category,
        index: variantIndex,
      ),
      tone: _toneFor(category: category, seed: seed),
      createdAt: intent.createdAt,
      localImagePaths: imagePaths,
    );
  }

  static List<String> _parseAttachments(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) {
              if (item is String) return item;
              if (item is Map) return item['url'] ?? item['path'];
              return null;
            })
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static List<String> _parseTags(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static List<InspirationMoment> buildFeed(List<FlowIntent> intents) {
    return intents.map(InspirationMoment.fromFlowIntent).toList();
  }
}

InspirationCategory _categoryFromTags(List<String> tags) {
  final normalized = tags.map((tag) => tag.toLowerCase().trim()).toList();
  if (normalized.any(
    (tag) => ['巧思', '想法', 'idea', 'thought', 'spark', '灵感'].contains(tag),
  )) {
    return InspirationCategory.ingenuity;
  }
  if (normalized.any(
    (tag) => ['心得', '体悟', '感悟', 'reflection', 'insight', '觉察'].contains(tag),
  )) {
    return InspirationCategory.reflection;
  }
  if (normalized.any(
    (tag) => ['心绪', '情绪', 'mood', 'emotion', '感受', '状态'].contains(tag),
  )) {
    return InspirationCategory.mood;
  }
  if (normalized.any(
    (tag) => ['纪事', '事件', '流水', '记录', 'record', 'event', 'log'].contains(tag),
  )) {
    return InspirationCategory.chronicle;
  }
  if (normalized.any(
    (tag) => ['摘录', '引言', '书摘', '金句', 'quote', 'excerpt'].contains(tag),
  )) {
    return InspirationCategory.excerpt;
  }
  return InspirationCategory.reflection;
}

String _categoryLabel(InspirationCategory category) {
  return switch (category) {
    InspirationCategory.ingenuity => '巧思',
    InspirationCategory.reflection => '体悟',
    InspirationCategory.mood => '心绪',
    InspirationCategory.chronicle => '纪事',
    InspirationCategory.excerpt => '摘录',
  };
}

InspirationTone _toneFor({
  required InspirationCategory category,
  required int seed,
}) {
  final palette = switch (category) {
    InspirationCategory.ingenuity => const [
      Color(0xFF4F6658),
      Color(0xFF9A8C62),
      Color(0xFFE9EFEA),
      Color(0xFFF7F1E5),
    ],
    InspirationCategory.reflection => const [
      Color(0xFF6B6257),
      Color(0xFF9B7B61),
      Color(0xFFF1ECE5),
      Color(0xFFE8EFEC),
    ],
    InspirationCategory.mood => const [
      Color(0xFF5B6F73),
      Color(0xFF8A7892),
      Color(0xFFE8F0EF),
      Color(0xFFF0E8ED),
    ],
    InspirationCategory.chronicle => const [
      Color(0xFF5F665C),
      Color(0xFF8A826F),
      Color(0xFFECEEE8),
      Color(0xFFF4F0E8),
    ],
    InspirationCategory.excerpt => const [
      Color(0xFF5C5368),
      Color(0xFF987A68),
      Color(0xFFEDEAF1),
      Color(0xFFF2ECE6),
    ],
  };
  final drift = (seed % 9) / 100;
  final radius = 16.0 + (seed % 7);
  final elevation = 0.035 + (seed % 5) * 0.006;
  return InspirationTone(
    tint: palette[0],
    accent: palette[1],
    gradient: [palette[2], palette[3]],
    wash: Color.lerp(palette[2], palette[3], (seed % 100) / 100)!,
    opacity: 0.08 + drift,
    radius: radius,
    elevation: elevation,
  );
}

int _stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
