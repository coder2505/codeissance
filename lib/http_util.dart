import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> postData(String message, double latitude, double longitude) async {
  var url = Uri.parse('https://rememberingly-unfrugal-lonna.ngrok-free.dev/api/citypulse');

  try {
    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'prompt': message, 'latitude': latitude, 'longitude': longitude}),
    );

    if (response.statusCode == 200) {
      print('Success: ${response.body}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body["response"] as String? ?? 'No response field found';
    } else {
      print('Request failed with status: ${response.statusCode}.');
      return 'Error: ${response.statusCode}';
    }
  } catch (e) {
    print('Error sending request: $e');
    return 'Error: $e';
  }
}

Future<String> getRouteSummary(LatLng start, LatLng end) async {
  var url = Uri.parse('https://rememberingly-unfrugal-lonna.ngrok-free.dev/api/routePlanner');
  try {
    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'startCoordinates': {'lat': start.latitude, 'lng': start.longitude},
        'endCoordinates': {'lat': end.latitude, 'lng': end.longitude}
      }),
    );

    if (response.statusCode == 200) {
      print('Success: ${response.body}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body["response"] as String? ?? 'No summary field found';
    } else {
      print('Request failed with status: ${response.statusCode}.');
      return 'Error: ${response.statusCode}';
    }
  } catch (e) {
    print('Error sending request: $e');
    return 'Error: $e';
  }
}