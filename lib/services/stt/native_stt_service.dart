import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'stt_service.dart';

/// Native speech recognition for iOS and Android (zh-TW).
class NativeSttService implements SttService {
  NativeSttService._();
  static final NativeSttService instance = NativeSttService._();

  static const _events = EventChannel('reminder/speech_events');
  static const _cmd = MethodChannel('reminder/speech_cmd');

  StreamSubscription<dynamic>? _sub;
  StreamController<String>? _ctrl;
  String _last = '';

  @override
  bool get isReady => true;

  @override
  Future<void> init() async {}

  @override
  Future<Stream<String>> start() async {
    if (Platform.isAndroid &&
        !(await Permission.microphone.request()).isGranted) {
      throw StateError('Microphone permission is required.');
    }

    await _stopInternal();
    _last = '';
    final controller = StreamController<String>();
    _ctrl = controller;

    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final text = event['text'] as String? ?? '';
      if (text.isNotEmpty && text != _last) {
        _last = text;
        _ctrl?.add(text);
      }
    }, onError: (Object error) => _ctrl?.addError(error));

    try {
      await _cmd.invokeMethod('start');
      if (!identical(_ctrl, controller)) {
        if (_ctrl == null) {
          try {
            await _cmd.invokeMethod('stop');
          } catch (_) {}
        }
        throw StateError('Speech recognition was stopped before it started.');
      }
    } catch (_) {
      if (identical(_ctrl, controller)) await _stopInternal();
      rethrow;
    }
    return controller.stream;
  }

  @override
  Future<String> stop() async {
    String raw = '';
    try {
      raw = await _cmd.invokeMethod<String>('stop') ?? '';
    } catch (_) {
      // The most recent partial remains available when native stop fails.
    }
    final result = raw.isEmpty ? _last : raw;
    await _stopInternal();
    return result;
  }

  Future<void> _stopInternal() async {
    await _sub?.cancel();
    _sub = null;
    await _ctrl?.close();
    _ctrl = null;
  }
}
