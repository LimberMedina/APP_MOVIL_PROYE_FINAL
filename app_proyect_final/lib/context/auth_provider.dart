// auth_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _token;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  String? get token => _token;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('token');
    if (storedToken != null) {
      _token = storedToken;
      await fetchUserProfile();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        _user = json.decode(response.body);
        notifyListeners();
      } else {
        logout();
      }
    } catch (e) {
      logout();
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        notifyListeners();
        return {'success': true};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Error al iniciar sesión',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de red o del servidor'};
    }
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _token = null;
    _user = null;
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> userData) {
    _user = userData;
    notifyListeners();
  }

  void setToken(String token) {
    _token = token;
    notifyListeners();
  }
}
