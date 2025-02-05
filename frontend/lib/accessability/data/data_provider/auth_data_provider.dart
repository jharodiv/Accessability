import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthDataProvider {
  final String _baseUrl = 'https://3-y2-aapwd-neon.vercel.app/api/v1/auth';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  //! Helper: Get Token from Storage
  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt');
  }

  //! Helper: Handle HTTP Responses
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final responseData = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      final errorMessage = responseData['message'] ?? 'An error occurred';
      throw Exception(errorMessage);
    }
  }

  //! Store Auth Data
  Future<void> _storeAuthData(Map<String, dynamic> data) async {
    await _storage.write(key: 'jwt', value: data['token']);
    await _storage.write(key: 'userId', value: data['userId']);
    if (data['handleId'] != null) {
      await _storage.write(key: 'handleId', value: data['handleId']);
    }
  }

  //! Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    print('Response Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    final data = await _handleResponse(response);

    await _storeAuthData(data);
    return data;
  }
}
