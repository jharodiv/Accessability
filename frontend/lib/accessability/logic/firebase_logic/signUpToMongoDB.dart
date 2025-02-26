import 'dart:convert';
import 'dart:io';

import 'package:AccessAbility/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:http/http.dart' as http;

class SignUpToMongoDB {
  final String _baseUrl =
      'https://3-y2-aapwd-neon.vercel.app/api/v1'; // Change to your machine's IP address

  SignUpToMongoDB();

  //! Register
  Future<Map<String, dynamic>> register(SignUpModel model, File? image) async {
    final url = Uri.parse('$_baseUrl/auth/signup');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(model.toJson());

    // Debug: Print the request details
    print('Request URL: $url');
    print('Request Headers: $headers');
    print('Request Body: $body');

    final response = await http.post(url, headers: headers, body: body);

    // Debug: Print the response details
    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode == 200) {
      return {'success': true, 'data': response.body};
    } else {
      return {'success': false, 'message': response.body};
    }
  }
}
