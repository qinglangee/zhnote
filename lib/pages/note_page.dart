import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../services/floating_ball_service.dart';
import '../services/note_service.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';
import 'settings_page.dart';
import 'view_notes_page.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  static const MethodChannel _desktopActions =
      MethodChannel('zhnote/desktop_actions');

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final NoteService _noteService = NoteService();

  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    settingsService.addListener(_onSettingsChanged);
    _desktopActions.setMethodCallHandler(_handleDesktopAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        floatingBallService.setVisible(settingsService.settings.showFloatingBall);
      }
    });
  }

  @override
  void dispose() {
    _desktopActions.setMethodCallHandler(null);
    settingsService.removeListener(_onSettingsChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 处理 Windows 托盘菜单与悬浮球点击发起的动作。
  Future<void> _handleDesktopAction(MethodCall call) async {
    if (!mounted) {
      return;
    }
    if (call.method == 'openMain') {
      // 已进入设置页等子页面时，回到首页笔记页。
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (call.method == 'openSettings') {
      // 已在设置页时不再重复打开。
      if (Navigator.of(context).canPop()) {
        return;
      }
      await _openSettings();
    }
  }

  void _onSettingsChanged() {
    if (mounted) {
      setState(() {});
      floatingBallService.setVisible(settingsService.settings.showFloatingBall);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: '选择笔记日期',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const SettingsPage()),
    );
  }

  Future<void> _openViewNotes() async {
    if (settingsService.settings.noteFilePath.trim().isEmpty) {
      await _promptSetup('还没有设置笔记文件位置，请先在设置中设置笔记文件位置。');
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const ViewNotesPage()),
    );
  }

  Future<void> _save() async {
    final AppSettings settings = settingsService.settings;

    if (settings.noteFilePath.trim().isEmpty) {
      await _promptSetup('还没有设置笔记文件位置，请先在设置中设置笔记文件位置。');
      return;
    }
    if (settings.startDay1 == null || settings.startDay2 == null) {
      await _promptSetup('还没有设置 startDay1 / startDay2，请先在设置中完成设置。');
      return;
    }

    final String text = _controller.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入笔记内容')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await _noteService.appendNote(
        date: _selectedDate,
        text: text,
        settings: settings,
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      _focusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到 ${dateWithWeekday(_selectedDate)}')),
      );
    } on NoteSaveException catch (error) {
      if (mounted) {
        await _showError(error.message);
      }
    } catch (error) {
      if (mounted) {
        await _showError('保存失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _promptSetup(String message) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('需要先完成设置'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
    if (go == true && mounted) {
      await _openSettings();
    }
  }

  Future<void> _showError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('保存失败'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('好'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = settingsService.settings;
    final bool filePathMissing = settings.noteFilePath.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记笔记'),
        actions: <Widget>[
          IconButton(
            tooltip: '查看笔记',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _openViewNotes,
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildDateSelector(theme),
              const SizedBox(height: 8),
              Text(
                filePathMissing ? '尚未设置笔记文件位置' : '保存到：${settings.noteFilePath}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: filePathMissing ? theme.colorScheme.error : null,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: '记录你的灵感…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.event_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              dateWithWeekday(_selectedDate),
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '修改日期',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
