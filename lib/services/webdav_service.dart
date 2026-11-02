import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';

/// WebDAV 同步失败时可以直接展示给用户的错误。
class WebDavException implements Exception {
  const WebDavException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 极简 WebDAV 客户端：只用到 GET / PUT / MKCOL。
class WebDavService {
  const WebDavService();

  /// 只有移动端（Android）才启用同步，桌面端始终不同步。
  bool isEnabled(AppSettings settings) {
    return Platform.isAndroid &&
        settings.webdavEnabled &&
        settings.webdavUrl.trim().isNotEmpty;
  }

  /// 远端文件名：优先使用设置里显式填写的文件名，
  /// 其次取本地笔记文件的名字，取不到时使用 zhnote.txt。
  String remoteFileName(AppSettings settings) {
    final String configured = settings.webdavRemoteFileName.trim();
    if (configured.isNotEmpty) {
      return configured.split(RegExp(r'[\\/]')).last;
    }

    final String path = settings.noteFilePath.trim();
    if (path.isEmpty) {
      return 'zhnote.txt';
    }

    String name = '';
    final Uri? uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'content' || uri.scheme == 'file')) {
      if (uri.pathSegments.isNotEmpty) {
        // pathSegments 已经是解码后的内容。
        name = uri.pathSegments.last;
      }
    } else {
      name = path.split(RegExp(r'[\\/]')).last;
    }

    // SAF 的 content URI 会带 documentId 前缀，例如 primary:AA_zhch/notes.txt
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.contains(':')) {
      name = name.split(':').last;
    }
    name = name.trim();
    return name.isEmpty ? 'zhnote.txt' : name;
  }

  /// 远端文件的完整地址。
  Uri fileUri(AppSettings settings) {
    final String base = settings.webdavUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final List<String> segments = <String>[
      ..._folderSegments(settings),
      remoteFileName(settings),
    ];
    final String encoded =
        segments.map(Uri.encodeComponent).join('/');
    return Uri.parse('$base/$encoded');
  }

  List<String> _folderSegments(AppSettings settings) {
    final String folder = settings.webdavFolder.trim();
    if (folder.isEmpty) {
      return const <String>[];
    }
    return folder
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .split('/')
        .where((String part) => part.isNotEmpty)
        .toList();
  }

  /// 下载远端笔记内容；远端文件不存在时返回 null。
  Future<String?> download(AppSettings settings) async {
    final HttpClient client = _createClient();
    try {
      final HttpClientRequest request = await client.getUrl(fileUri(settings));
      _applyAuth(request, settings);
      final HttpClientResponse response = await request.close();
      final int status = response.statusCode;

      if (status == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
        await response.drain<void>();
        throw const WebDavException('WebDAV 认证失败，请检查用户名和密码。');
      }
      if (status >= HttpStatus.multipleChoices) {
        await response.drain<void>();
        throw WebDavException('下载笔记文件失败（HTTP $status）。');
      }

      return decodedUtf8(await _readBytes(response));
    } on SocketException catch (error) {
      throw WebDavException('无法连接 WebDAV 服务器：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// 上传（覆盖）远端笔记文件，目录不存在时自动创建。
  Future<void> upload(AppSettings settings, String content) async {
    final HttpClient client = _createClient();
    try {
      final Uri uri = fileUri(settings);
      int status = await _put(client, uri, settings, content);
      if (status == HttpStatus.conflict) {
        await _ensureFolders(client, settings);
        status = await _put(client, uri, settings, content);
      }
      if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
        throw const WebDavException('WebDAV 认证失败，请检查用户名和密码。');
      }
      if (status >= HttpStatus.multipleChoices) {
        throw WebDavException('上传笔记文件失败（HTTP $status）。');
      }
    } on SocketException catch (error) {
      throw WebDavException('无法连接 WebDAV 服务器：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _createClient() {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 5);
  }

  void _applyAuth(HttpClientRequest request, AppSettings settings) {
    final String username = settings.webdavUsername.trim();
    if (username.isEmpty) {
      return;
    }
    final String token =
        base64Encode(utf8.encode('$username:${settings.webdavPassword}'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $token');
  }

  Future<int> _put(
    HttpClient client,
    Uri uri,
    AppSettings settings,
    String content,
  ) async {
    final List<int> bytes = utf8.encode(content);
    final HttpClientRequest request = await client.putUrl(uri);
    _applyAuth(request, settings);
    request.headers.contentType =
        ContentType('text', 'plain', charset: 'utf-8');
    request.headers.contentLength = bytes.length;
    request.add(bytes);
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<List<int>> _readBytes(HttpClientResponse response) async {
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  String decodedUtf8(List<int> bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 逐级创建 WebDAV 目录（MKCOL）。
  Future<void> _ensureFolders(HttpClient client, AppSettings settings) async {
    final String base = settings.webdavUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final List<String> segments = _folderSegments(settings);
    String current = base;
    for (final String segment in segments) {
      current = '$current/${Uri.encodeComponent(segment)}';
      final HttpClientRequest request = await client.openUrl('MKCOL', Uri.parse(current));
      _applyAuth(request, settings);
      final HttpClientResponse response = await request.close();
      await response.drain<void>();
      final int status = response.statusCode;
      if (status == HttpStatus.created ||
          status == HttpStatus.ok ||
          status == HttpStatus.methodNotAllowed ||
          status == HttpStatus.movedPermanently) {
        continue;
      }
      if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
        throw const WebDavException('WebDAV 认证失败，请检查用户名和密码。');
      }
      throw WebDavException('创建 WebDAV 目录失败（HTTP $status）。');
    }
  }
}

const WebDavService webDavService = WebDavService();
