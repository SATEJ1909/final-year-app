import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A simple data class to hold the response from a successful login.
class LoginResponse {
  final String token;
  final String role; // 'driver' or 'police'
  final String id;

  LoginResponse({required this.token, required this.role, required this.id});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      role: json['role'],
      id: json['id'].toString(),
    );
  }
}


/// A service class to handle authentication-related API calls.
class AuthService {
  // --- IMPORTANT ---
  // For Android emulator, use 10.0.2.2 instead of localhost.
  // For physical devices, use your computer's local IP address.
  static const String _baseUrl = 'http://192.168.22.33:5000/api/v1/user';

  /// Registers a new user by sending their details to the backend.
  ///
  /// Takes [username], [password], and [role] ('Ambulance Driver' or 'Traffic Police').
  /// Returns `true` on success, or throws an exception on failure.
  Future<bool> signUp({
    required String username,
    required String password,
    required String role,
  }) async {
    // Convert the user-friendly role to a simple string for the backend.
    final String apiRole =
        role == 'Ambulance Driver' ? 'driver' : 'police';

    final Uri signUpUrl = Uri.parse('$_baseUrl/signup');

    try {
      final response = await http.post(
        signUpUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
          'role': apiRole,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Successfully created the user.
        debugPrint('Signup successful: ${response.body}');
        final responseBody = jsonDecode(response.body);
        // Extract token/id/role from response and persist.
        final token = responseBody['token'];
        final role = responseBody['role'];
        final id = responseBody['id']?.toString();
        final prefs = await SharedPreferences.getInstance();
        if (token != null) await prefs.setString('auth_token', token);
        if (role != null) await prefs.setString('user_role', role);
        if (id != null) await prefs.setString('user_id', id);
        return true;
      } else {
        // Handle server errors (e.g., user already exists, validation error).
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to sign up: ${errorBody['message']}');
      }
    } catch (e) {
      // Handle network errors or other exceptions.
      debugPrint('Signup error: $e');
      throw Exception('Could not connect to the server. Please try again later.');
    }
  }

  /// Logs in a user by sending their credentials to the backend.
  ///
  /// Takes [username] and [password].
  /// Returns a `LoginResponse` object containing the auth token and user role on success.
  /// Throws an exception on failure.
  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final Uri loginUrl = Uri.parse('$_baseUrl/login');

    try {
      final response = await http.post(
        loginUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // Successfully logged in.
        debugPrint('Login successful: ${response.body}');
        final responseBody = jsonDecode(response.body);
        final loginResp = LoginResponse.fromJson(responseBody);

        // Persist token and role to shared preferences for later use.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', loginResp.token);
  await prefs.setString('user_role', loginResp.role);
  await prefs.setString('user_id', loginResp.id);

        return loginResp;
      } else {
        // Handle server errors (e.g., invalid credentials).
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to log in: ${errorBody['message']}');
      }
    } catch (e) {
      // Handle network errors or other exceptions.
      debugPrint('Login error: $e');
      throw Exception('Could not connect to the server. Please try again later.');
    }
  }

  /// Return saved auth token or null if not available.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Return saved role or null if not available.
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  /// Return saved user id or null if not available.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }
}

