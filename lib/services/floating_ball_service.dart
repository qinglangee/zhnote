import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 控制平台悬浮球（Windows 与 Android）。
class FloatingBallService {
  static const MethodChannel _channel = MethodChannel('zhnote/floating_ball');

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.android;

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Android 需要“悬浮在其他应用之上”权限，其它平台始终返回 true。
  Future<bool> hasPermission() async {
    if (!isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException catch (error) {
      debugPrint('读取悬浮窗权限失败：${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 打开系统的悬浮窗权限设置页（仅 Android）。
  Future<void> openPermissionSettings() async {
    if (!isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openPermissionSettings');
    } on PlatformException catch (error) {
      debugPrint('打开悬浮窗权限设置失败：${error.message}');
    } on MissingPluginException {
      debugPrint('当前平台未实现悬浮窗权限设置');
    }
  }

  /// 显示或隐藏悬浮球。Android 缺少权限时返回 false 且不会显示。
  Future<bool> setVisible(bool visible) async {
    if (!_supported) {
      return false;
    }
    if (visible && isAndroid && !await hasPermission()) {
      return false;
    }
    try {
      final bool? shown =
          await _channel.invokeMethod<bool>(visible ? 'show' : 'hide');
      return shown ?? true;
    } on PlatformException catch (error) {
      debugPrint('悬浮球控制失败：${error.message}');
      return false;
    } on MissingPluginException {
      debugPrint('当前平台未实现悬浮球');
      return false;
    }
  }

  /// 设置悬浮球不透明度（0.05 - 1.0）。
  Future<void> setOpacity(double opacity) async {
    if (!_supported) {
      return;
    }
    final double value = opacity.clamp(0.05, 1.0).toDouble();
    try {
      await _channel.invokeMethod<void>(
        'setOpacity',
        <String, double>{'opacity': value},
      );
    } on PlatformException catch (error) {
      debugPrint('设置悬浮球透明度失败：${error.message}');
    } on MissingPluginException {
      debugPrint('当前平台未实现悬浮球透明度');
    }
  }

  /// 设置悬浮球大小（逻辑像素 / DP，5 - 96）。
  Future<void> setSize(double size) async {
    if (!_supported) {
      return;
    }
    final double value = size.clamp(5.0, 96.0).toDouble();
    try {
      await _channel.invokeMethod<void>(
        'setSize',
        <String, double>{'size': value},
      );
    } on PlatformException catch (error) {
      debugPrint('设置悬浮球大小失败：${error.message}');
    } on MissingPluginException {
      debugPrint('当前平台未实现悬浮球大小');
    }
  }
}

final FloatingBallService floatingBallService = FloatingBallService();
