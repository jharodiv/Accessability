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
    if (data['token'] != null && data['user'] != null) {
      await _storage.write(key: 'jwt', value: data['token']);
      await _storage.write(
          key: 'userId',
          value: data['user']['id']); // Ensure the userId is correct
      if (data['user']['handleId'] != null) {
        await _storage.write(key: 'handleId', value: data['user']['handleId']);
      }
    } else {
      throw Exception('Missing token or user data');
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

    // Ensure we have all the necessary fields in the response
    if (data['token'] == null ||
        data['data'] == null ||
        data['data']['user'] == null) {
      throw Exception('Missing token or user data');
    }

    // Storing the token and user data correctly
    await _storeAuthData({
      'token': data['token'],
      'user': data['data']['user'], // Correct user data structure
    });

    return data;
  }

  //! Send Verification Code
  Future<void> sendVerificationCode(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sendVerificationCode'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    final data = await _handleResponse(response);
    print('Verification Code Sent: ${data['message']}');
  }

  //! Update User Onboarding
  Future<void> completeOnboarding() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.put(
      Uri.parse(
          'https://3-y1-cryptotel-hazel.vercel.app/api/v1/user/updateHasCompletedOnboarding'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'settings': {
          'hasCompletedOnboarding': true,
        }
      }),
    );

    if (response.statusCode != 200) {
      final errorResponse = json.decode(response.body);
      String errorMessage = errorResponse['message'] ?? 'An error occurred';
      throw Exception('Failed to complete onboarding: $errorMessage');
    }
  }
}
