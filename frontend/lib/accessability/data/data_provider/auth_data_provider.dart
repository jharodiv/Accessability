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
}
