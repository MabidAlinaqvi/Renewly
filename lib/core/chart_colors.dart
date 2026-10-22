import 'package:flutter/material.dart';

/// Categorical colours in their validated fixed order (colour-blind safe on
/// adjacent pairs). A category keeps its colour wherever it appears and
/// whatever its rank. Nine named categories don't fit eight slots, so
/// Utilities joins Other in grey.
const _slots = {
  'Entertainment': Color(0xFF2A78D6),
  'Music': Color(0xFFEB6834),
  'Cloud & storage': Color(0xFF1BAF7A),
  'Software': Color(0xFFEDA100),
  'AI tools': Color(0xFFE87BA4),
  'Shopping': Color(0xFF008300),
  'Health & fitness': Color(0xFF6250D6),
  'News & reading': Color(0xFFE34948),
};

const otherColor = Color(0xFF8E8C86);
const otherLabel = 'Other';

Color categoryColor(String category) => _slots[category] ?? otherColor;

/// Categories with their own colour, biggest first, then one grey "Other"
/// holding the rest, so charts never show more than [maxSlices] pieces.
List<({String label, Color color, double amount})> categorySlices(
  Map<String, double> byCategory, {
  int maxSlices = 6,
}) {
  final named = [
    for (final e in byCategory.entries)
      if (_slots.containsKey(e.key) && e.value > 0) e,
  ]..sort((a, b) => b.value.compareTo(a.value));
  final shown = named.take(maxSlices - 1).toList();
  final rest = byCategory.values.fold(0.0, (a, b) => a + b) - shown.fold(0.0, (a, e) => a + e.value);
  return [
    for (final e in shown) (label: e.key, color: categoryColor(e.key), amount: e.value),
    if (rest > 0.0001) (label: otherLabel, color: otherColor, amount: rest),
  ];
}
