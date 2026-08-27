import 'dart:io';

import 'package:flutter/services.dart';

import '../semantic/name_corrector.dart';

class PersonSpanService {
  const PersonSpanService();

  static const _channel = MethodChannel('reminder/person_spans');

  Future<List<PersonSpan>> detect(String text) async {
    if (!Platform.isAndroid || text.isEmpty) return const [];
    try {
      final words = await _channel.invokeListMethod<String>('detect', text);
      return locateWords(text, words ?? const []);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  static List<PersonSpan> locateWords(String text, List<String> words) {
    final spans = <PersonSpan>[];
    var searchFrom = 0;
    for (final word in words) {
      if (word.isEmpty) continue;
      final start = text.indexOf(word, searchFrom);
      if (start < 0) continue;
      final end = start + word.length;
      spans.add(
        PersonSpan(
          text.substring(0, start).runes.length,
          text.substring(0, end).runes.length,
        ),
      );
      searchFrom = end;
    }
    return spans;
  }
}
