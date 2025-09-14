import 'dart:convert';
import 'package:flutter/services.dart';

class ContactService {
  static const MethodChannel _channel =
      MethodChannel('com.example.frontend/contacts');

  static Future<List<Map<String, String>>> getContacts() async {
    try {
      final String contactsJson = await _channel.invokeMethod('getContacts');
      final List<dynamic> contactsList =
          json.decode(contactsJson) as List<dynamic>;

      return contactsList.map((contact) {
        return {
          'name': contact['name']?.toString() ?? '',
          'phone': contact['phone']?.toString() ?? '',
        };
      }).toList();
    } on PlatformException catch (e) {
      print("Failed to get contacts: '${e.message}'");
      return [];
    } catch (e) {
      print("Error parsing contacts: $e");
      return [];
    }
  }
}
