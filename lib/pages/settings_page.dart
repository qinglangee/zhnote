import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pathController;
  late bool _showFloatingBall;
  DateTime? _startDay1;
  DateTime? _startDay2;

  @override
  void initState() {
    super.initState();
    final AppSettings settings = settingsService.settings;
    _pathController = TextEditingController(text: settings.noteFilePath);
    _showFloatingBall = settings.showFloatingBall;
    _startDay1 = settings.startDay1;
    _startDay2 = settings.startDay2;
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await settingsService.save(
      AppSettings(
        showFloatingBall: _showFloatingBall,
        noteFilePath: _pathController.text.trim(),
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
    Navigator.of(context).pop();
  }

  Future<void> _pickExistingFile() async {
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('笔记文件位置', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _pathController,
                decoration: const InputDecoration(
                  hintText: r'例如 D:\notes\notes.txt',
                  border: OutlineInputBorder(),
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
