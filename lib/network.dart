import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps the app's traffic on the Wi-Fi network (Android only).
///
/// On a Wi-Fi that has no internet, Android can route an app over mobile data,
/// which cannot reach the laptop. Binding to Wi-Fi fixes that. Cheap enough to
/// call before every send or search, which also keeps up with network changes.
class WifiBinder {
  static const _channel = MethodChannel('flux/network');

  static Future<void> bind() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('bindWifi');
    } catch (_) {
      // Plugin missing (tests) or the OS refused. Default routing still works
      // on most networks, so carry on.
    }
  }
}
