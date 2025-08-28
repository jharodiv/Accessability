import 'dart:convert';
import 'package:http/http.dart' as http;

class DoryService {
  static Future<Map<String, dynamic>> predictCommand(String text) async {
    final url =
        Uri.parse("https://jharodiv-accessability.hf.space/api/predict");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to get prediction: ${response.body}");
    }
  }
}
