import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final String? baseUrl = dotenv.env['API_URL'];

enum HttpMethod { get, post, put, patch, delete }

Future<dynamic> apiRequest({
  required String endpoint,
  required HttpMethod method,
  bool useToken = false,
  bool showError = true,
  Map<String, dynamic>? body,
  BuildContext? context,
}) async {
  final uri = Uri.parse('$baseUrl$endpoint');

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  if (useToken) {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  final encodedBody = body != null ? jsonEncode(body) : null;

  http.Response response;

  try {
    switch (method) {
      case HttpMethod.get:
        response = await http.get(uri, headers: headers);
      case HttpMethod.post:
        response = await http.post(uri, headers: headers, body: encodedBody);
      case HttpMethod.put:
        response = await http.put(uri, headers: headers, body: encodedBody);
      case HttpMethod.patch:
        response = await http.patch(uri, headers: headers, body: encodedBody);
      case HttpMethod.delete:
        response = await http.delete(uri, headers: headers, body: encodedBody);
    }
  } catch (e) {
    if (showError && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сүлжээний алдаа: $e')),
      );
    }
    return null;
  }

  final json = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return json;
  }

  if (showError && context != null && context.mounted) {
    final message =
        json is Map ? (json['message'] ?? json.toString()) : json.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Center(child: Text(message.toString()))),
    );
  }

  return null;
}
