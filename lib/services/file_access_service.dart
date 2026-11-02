import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 上通过 SAF（系统文件选择器）读写任意位置的笔记文件。
///
/// Windows 直接使用文件系统路径，不走这个通道。
class FileAccessService {
  static const MethodChannel _channel = MethodChannel('zhnote/file_access');

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// 打开系统文件选择器，返回 content URI；用户取消时返回 null。
  Future<String?> pickFile() {
    return _channel.invokeMethod<String>('pickFile');
  }

  /// 通过系统"新建文件"对话框创建并返回 content URI；用户取消时返回 null。
  Future<String?> createFile({String fileName = 'notes.txt'}) {
    return _channel.invokeMethod<String>(
      'createFile',
      <String, String>{'fileName': fileName},
    );
  }

  /// 读取文本；文件不存在时返回 null。
  Future<String?> readText(String uri) {
    return _channel.invokeMethod<String>(
      'readText',
      <String, String>{'uri': uri},
    );
  }

  /// 以 UTF-8 覆盖写入文本。
  Future<void> writeText(String uri, String text) {
    return _channel.invokeMethod<void>(
      'writeText',
      <String, Object>{'uri': uri, 'text': text},
    );
  }
}

final FileAccessService fileAccessService = FileAccessService();
