import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 控制平台悬浮球。目前仅 Windows 已实现，Android 将在后续阶段接入。
class FloatingBallService {
  static const MethodChannel _channel = MethodChannel('zhnote/floating_ball');

  bool get _supported => defaultTargetPlatform == TargetPlatform.windows;

  Future<void> setVisible(bool visible) async {
    if (!_supported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(visible ? 'show' : 'hide');
    } on PlatformException catch (error) {
      debugPrint('悬浮球控制失败：${error.message}');
    } on MissingPluginException {
      debugPrint('当前平台未实现悬浮球');
    }
  }
}

final FloatingBallService floatingBallService = FloatingBallService();
