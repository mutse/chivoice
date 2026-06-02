import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/settings/settings_provider.dart';

class ImePlatformBridge {
  ImePlatformBridge._();

  static const MethodChannel _channel = MethodChannel('chivoice/ime');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> syncSettings(SettingsState settings) async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('syncSettings', {
        'languageCode': settings.languageCode,
        'smartPunctuation': settings.smartPunctuation,
        'skinName': settings.skin.name,
        'primaryColor': settings.skin.primaryValue,
        'secondaryColor': settings.skin.secondaryValue,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> openInputMethodSettings() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openInputMethodSettings');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> showInputMethodPicker() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('showInputMethodPicker');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
