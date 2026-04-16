import 'package:flutter/material.dart';
import 'supabase_service.dart';

class ThemeController extends ChangeNotifier {
  bool _darkMode = false;
  Map<String, dynamic> _settingsCache = {
    'dark_mode': false,
    'meeting_reminders': true,
    'contribution_reminders': true,
    'loan_reminders': false,
  };

  bool get darkMode => _darkMode;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadTheme(String memberId) async {
    final settings = await SupabaseService.getMemberSettings(
      memberId: memberId,
    );

    _settingsCache = settings;
    _darkMode = settings['dark_mode'] == true;
    notifyListeners();
  }

  void setSettings(Map<String, dynamic> settings) {
    _settingsCache = settings;
    _darkMode = settings['dark_mode'] == true;
    notifyListeners();
  }

  Future<void> toggleDarkMode(String memberId, bool value) async {
    _darkMode = value;
    _settingsCache['dark_mode'] = value;
    notifyListeners();

    await SupabaseService.saveMemberSettings(
      memberId: memberId,
      darkMode: _settingsCache['dark_mode'] == true,
      meetingReminders: _settingsCache['meeting_reminders'] == true,
      contributionReminders: _settingsCache['contribution_reminders'] == true,
      loanReminders: _settingsCache['loan_reminders'] == true,
    );
  }
}
