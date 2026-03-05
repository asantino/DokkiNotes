import 'package:flutter/material.dart';
import '../theme/dokki_theme.dart';

class HashtagTextController extends TextEditingController {
  HashtagTextController({super.text});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<InlineSpan> children = [];
    final pattern = RegExp(r"(#[a-zA-Z0-9а-яА-ЯёЁ_]+)");

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match[0],
          style: style?.copyWith(
              color: DokkiColors.primaryTeal, fontWeight: FontWeight.bold),
        ));
        return "";
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return "";
      },
    );

    return TextSpan(style: style, children: children);
  }

  // Метод, чтобы достать список тегов из текста
  List<String> extractTags() {
    final pattern = RegExp(r"(#[a-zA-Z0-9а-яА-ЯёЁ_]+)");
    final matches = pattern.allMatches(text);
    return matches
        .map((m) => m.group(0)!)
        .toSet()
        .toList(); // toSet убирает дубликаты
  }
}
