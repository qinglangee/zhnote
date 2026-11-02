import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/file_access_service.dart';
import '../services/floating_ball_service.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pathController;
  late final TextEditingController _webdavUrlController;
  late final TextEditingController _webdavUsernameController;
  late final TextEditingController _webdavPasswordController;
  late final TextEditingController _webdavFolderController;
  late bool _showFloatingBall;
  bool _webdavEnabled = false;
  double _opacity = 1.0;
  double _size = 64.0;
  DateTime? _startDay1;
  DateTime? _startDay2;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = settingsService.settings;
    _pathController = TextEditingController(text: settings.noteFilePath);
    _webdavUrlController = TextEditingController(text: settings.webdavUrl);
    _webdavUsernameController =
        TextEditingController(text: settings.webdavUsername);
    _webdavPasswordController =
        TextEditingController(text: settings.webdavPassword);
    _webdavFolderController = TextEditingController(text: settings.webdavFolder);
    _showFloatingBall = settings.showFloatingBall;
    _webdavEnabled = settings.webdavEnabled;
    _opacity = settings.floatingBallOpacity;
    _size = settings.floatingBallSize;
    _startDay1 = settings.startDay1;
    _startDay2 = settings.startDay2;
  }

  @override
  void dispose() {
    _pathController.dispose();
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    _webdavFolderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_webdavEnabled && _webdavUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('启用 WebDAV 同步时必须填写服务器地址')),
      );
      return;
    }

    final bool needsOverlayPermission = _showFloatingBall &&
        floatingBallService.isAndroid &&
        !await floatingBallService.hasPermission();

    await settingsService.save(
      AppSettings(
        showFloatingBall: _showFloatingBall,
        floatingBallOpacity: _opacity,
        floatingBallSize: _size,
        noteFilePath: _pathController.text.trim(),
        webdavEnabled: _webdavEnabled,
        webdavUrl: _webdavUrlController.text.trim(),
        webdavUsername: _webdavUsernameController.text.trim(),
        webdavPassword: _webdavPasswordController.text,
        webdavFolder: _webdavFolderController.text.trim(),
        startDay1: _startDay1,
        startDay2: _startDay2,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );
    if (needsOverlayPermission) {
      await _promptOverlayPermission();
      if (!mounted) {
        return;
      }
    }
    Navigator.of(context).pop();
  }

  Future<void> _promptOverlayPermission() async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('需要悬浮窗权限'),
          content: const Text(
            '显示悬浮球需要“悬浮在其他应用之上”的权限，请在系统设置中允许 zhnote 使用该权限。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去授权'),
            ),
          ],
        );
      },
    );
    if (go == true) {
      await floatingBallService.openPermissionSettings();
    }
  }

  Future<void> _pickExistingFile() async {
    if (fileAccessService.isAndroid) {
      final String? uri = await fileAccessService.pickFile();
      if (uri == null || !mounted) {
        return;
      }
      setState(() {
        _pathController.text = uri;
      });
      return;
    }
    final PlatformFile? file = await FilePicker.pickFile(
      dialogTitle: '选择笔记文件',
      type: FileType.custom,
      allowedExtensions: <String>['txt'],
    );
    final String? path = file?.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _pathController.text = path;
    });
  }

  Future<void> _createNewFile() async {
    if (fileAccessService.isAndroid) {
      final String? uri = await fileAccessService.createFile();
      if (uri == null || !mounted) {
        return;
      }
      setState(() {
        _pathController.text = uri;
      });
      return;
    }
    final Uri? uri = await FilePicker.saveFile(
      dialogTitle: '选择笔记文件保存位置',
      fileName: 'notes.txt',
      mimeType: 'text/plain',
      bytes: Uint8List(0),
    );
    if (uri == null || !mounted) {
      return;
    }
    final String path = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
    setState(() {
      _pathController.text = path;
    });
  }

  Future<void> _pickStartDay({required bool isStartDay1}) async {
    final DateTime? current = isStartDay1 ? _startDay1 : _startDay2;
    final DateTime now = DateTime.now();
    final DateTime initial = current ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: isStartDay1 ? '选择 startDay1' : '选择 startDay2',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStartDay1) {
        _startDay1 = DateTime(picked.year, picked.month, picked.day);
      } else {
        _startDay2 = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            SwitchListTile(
              title: const Text('显示悬浮球'),
              subtitle: const Text('悬浮在所有窗口之上，可拖动，点击回到笔记页'),
              value: _showFloatingBall,
              onChanged: (bool value) {
                setState(() {
                  _showFloatingBall = value;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('悬浮球透明度', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '${(_opacity * 100).round()}%',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Slider(
                    value: _opacity,
                    min: 0.05,
                    max: 1.0,
                    divisions: 19,
                    label: '${(_opacity * 100).round()}%',
                    onChanged: _showFloatingBall
                        ? (double value) {
                            setState(() {
                              _opacity = value;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('悬浮球大小', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        '${_size.round()}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Slider(
                    value: _size,
                    min: 5.0,
                    max: 96.0,
                    divisions: 91,
                    label: '${_size.round()}',
                    onChanged: _showFloatingBall
                        ? (double value) {
                            setState(() {
                              _size = value;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('笔记文件位置', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _pathController,
                decoration: InputDecoration(
                  hintText: fileAccessService.isAndroid
                      ? '通过下方按钮选择 txt 文件'
                      : r'例如 D:\notes\notes.txt',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _pickExistingFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择已有文件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _createNewFile,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('新建文件'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '笔记文件为 UTF-8 编码的 txt 文件。',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('startDay1'),
              subtitle: Text(
                _startDay1 == null
                    ? '未设置（必填）'
                    : '${dateKey(_startDay1!)} ${weekdayLabel(_startDay1!)}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickStartDay(isStartDay1: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                '用于计算“没练功”的天数，以及超过的年数。',
                style: theme.textTheme.bodySmall,
              ),
            ),
            ListTile(
              title: const Text('startDay2'),
              subtitle: Text(
                _startDay2 == null
                    ? '未设置（必填）'
                    : '${dateKey(_startDay2!)} ${weekdayLabel(_startDay2!)}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickStartDay(isStartDay1: false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                '用于计算“第 X 天”。',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (Platform.isAndroid) ...<Widget>[
              const Divider(),
              SwitchListTile(
                title: const Text('启用 WebDAV 同步'),
                subtitle: const Text('保存笔记前先下载服务器上的最新文件，保存后再上传'),
                value: _webdavEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _webdavEnabled = value;
                  });
                },
              ),
              if (_webdavEnabled) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://example.com/dav/',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _webdavUsernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _webdavPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _webdavFolderController,
                    decoration: const InputDecoration(
                      labelText: '文件夹路径',
                      hintText: '例如 notes，可为空',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '同步使用本地笔记文件名；服务器目录不存在时会自动创建。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存设置'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
