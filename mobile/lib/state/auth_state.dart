import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final ApiClient api;
  AppUser? user;
  bool booting = true;
  String? error;

  bool get isLoggedIn => user != null && api.token != null;

  Future<void> bootstrap() async {
    booting = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      api.setToken(token);
      try {
        user = await api.me();
      } catch (_) {
        await prefs.remove('token');
        api.setToken(null);
        user = null;
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    error = null;
    notifyListeners();
    try {
      final data = await api.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        role: role,
        phone: phone,
      );
      if (data['token'] is String && data['user'] is Map<String, dynamic>) {
        user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token'] as String);
      }
      notifyListeners();
      return data;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> login(String email, String password, {required String division}) async {
    error = null;
    notifyListeners();
    try {
      final data = await api.login(email.trim(), password, division: division);
      user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token'] as String);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void applyUser(AppUser next) {
    user = next;
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    user = null;
    notifyListeners();
  }

  String homeRouteForRole() {
    switch (user?.role) {
      case 'tutor':
      case 'lecturer':
      case 'lawyer':
      case 'counsel':
        return '/tutor';
      case 'admin':
        return '/welcome';
      default:
        return '/student';
    }
  }
}
