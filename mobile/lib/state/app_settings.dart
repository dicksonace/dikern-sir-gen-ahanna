import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;

  static const _key = 'app_theme';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = switch (prefs.getString(_key)) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode value) async {
    if (mode == value) return;
    mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value == ThemeMode.dark ? 'dark' : 'light');
  }
}
