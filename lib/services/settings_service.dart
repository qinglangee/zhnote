import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../utils/date_utils.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyShowFloatingBall = 'show_floating_ball';
  static const String _keyFloatingBallOpacity = 'floating_ball_opacity';
  static const String _keyFloatingBallSize = 'floating_ball_size';
  static const String _keyWebdavEnabled = 'webdav_enabled';
  static const String _keyWebdavUrl = 'webdav_url';
  static const String _keyWebdavUsername = 'webdav_username';
  static const String _keyWebdavPassword = 'webdav_password';
  static const String _keyWebdavFolder = 'webdav_folder';
  static const String _keyNoteFilePath = 'note_file_path';
  static const String _keyStartDay1 = 'start_day1';
  static const String _keyStartDay2 = 'start_day2';

  AppSettings _settings = AppSettings.empty;

  AppSettings get settings => _settings;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      showFloatingBall: prefs.getBool(_keyShowFloatingBall) ?? true,
      floatingBallOpacity: prefs.getDouble(_keyFloatingBallOpacity) ?? 1.0,
      floatingBallSize: prefs.getDouble(_keyFloatingBallSize) ?? 64.0,
      webdavEnabled: prefs.getBool(_keyWebdavEnabled) ?? false,
      webdavUrl: prefs.getString(_keyWebdavUrl) ?? '',
      webdavUsername: prefs.getString(_keyWebdavUsername) ?? '',
      webdavPassword: prefs.getString(_keyWebdavPassword) ?? '',
      webdavFolder: prefs.getString(_keyWebdavFolder) ?? '',
      noteFilePath: prefs.getString(_keyNoteFilePath) ?? '',
      startDay1: _parseDate(prefs.getString(_keyStartDay1)),
      startDay2: _parseDate(prefs.getString(_keyStartDay2)),
    );
    notifyListeners();
  }

  Future<void> save(AppSettings settings) async {
    _settings = settings;
    notifyListeners();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowFloatingBall, settings.showFloatingBall);
    await prefs.setDouble(_keyFloatingBallOpacity, settings.floatingBallOpacity);
    await prefs.setDouble(_keyFloatingBallSize, settings.floatingBallSize);
    await prefs.setBool(_keyWebdavEnabled, settings.webdavEnabled);
    await prefs.setString(_keyWebdavUrl, settings.webdavUrl);
    await prefs.setString(_keyWebdavUsername, settings.webdavUsername);
    await prefs.setString(_keyWebdavPassword, settings.webdavPassword);
    await prefs.setString(_keyWebdavFolder, settings.webdavFolder);
    await prefs.setString(_keyNoteFilePath, settings.noteFilePath);

    final DateTime? startDay1 = settings.startDay1;
    if (startDay1 == null) {
      await prefs.remove(_keyStartDay1);
    } else {
      await prefs.setString(_keyStartDay1, dateKey(startDay1));
    }

    final DateTime? startDay2 = settings.startDay2;
    if (startDay2 == null) {
      await prefs.remove(_keyStartDay2);
    } else {
      await prefs.setString(_keyStartDay2, dateKey(startDay2));
    }
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

final SettingsService settingsService = SettingsService();
