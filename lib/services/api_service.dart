import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
    if (showError) {
      Fluttertoast.showToast(
        msg: 'Сүлжээний алдаа: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
    return null;
  }

  final json = jsonDecode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    return json;
  }

  if (showError) {
    final message =
        json is Map ? (json['message'] ?? json.toString()) : json.toString();
    Fluttertoast.showToast(
      msg: message.toString(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  return null;
}
