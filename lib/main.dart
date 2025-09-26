import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'http_util.dart';

// A simple class to model a chat message
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MapSample(),
  ));
}

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  // --- State Variables ---
  final TextEditingController _searchController = TextEditingController();
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<dynamic> _suggestions = [];

  LatLng? _currentLatLng;
  String? _eta;
  String? _distance;
  bool _isLoading = false;

  String? _selectedGoal;
  DateTime? _deadline;

  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [];

  String? _routeSummary; // ✨ NEW: State variable for the summary
  bool _isSummaryLoading = false; // ✨ NEW: Loading state for the summary

  // TODO: Add your Google Maps API key here
  final String _apiKey = "AIzaSyBAvUgw3DsmwlzJUXHQ693ClGK7jpsh4Fg";

  String? _mapStyle;
  final Set<Marker> _eventMarkers = {};

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_style.json').then((string) {
      _mapStyle = string;
    });
    _loadEventMarkers();
    _determinePosition();
  }

  // ✨ NEW: Function to get the route summary from your API
  Future<String> getRouteSummary(LatLng start, LatLng end) async {
    var url = Uri.parse('https://rememberingly-unfrugal-lonna.ngrok-free.dev/api/routePlanner');
    try {
      var response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({
          'startCoordinates': {'latitude': start.latitude, 'longitude': start.longitude},
          'endCoordinates': {'latitude': end.latitude, 'longitude': end.longitude}
        }),
      );

      if (response.statusCode == 200) {
        print('Success: ${response.body}');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body["response"] as String? ?? 'No summary field found';
      } else {
        print('Request failed with status: ${response.statusCode}.');
        return 'Error fetching summary: Status ${response.statusCode}';
      }
    } catch (e) {
      print('Error sending request: $e');
      return 'Error fetching summary: $e';
    }
  }

  Future<void> _loadEventMarkers() async {
    final String jsonString = await rootBundle.loadString('assets/events.json');
    final data = jsonDecode(jsonString);
    final List<dynamic> events = data['events'];
    Set<Marker> markers = {};
    for (var event in events) {
      final String eventType = event['type'];
      double hue;
      switch (eventType) {
        case 'food':
          hue = BitmapDescriptor.hueOrange;
          break;
        case 'utility_alert':
          hue = BitmapDescriptor.hueAzure;
          break;
        default:
          hue = BitmapDescriptor.hueRed;
      }
      markers.add(
        Marker(
          markerId: MarkerId(event['id']),
          position: LatLng(event['latitude'], event['longitude']),
          infoWindow: InfoWindow(
            title: event['name'],
            snippet: event['summary'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }
    setState(() {
      _eventMarkers.addAll(markers);
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });
    _goToCurrentLocation();
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLatLng == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng!, 15));
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? DateTime.now()),
    );
    if (pickedTime == null) return;

    setState(() {
      _deadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _showChatBottomSheet() {
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
          text: "Hi there! How can I help you with your route to ${_searchController.text}?",
          isUser: false));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void handleSendMessage() async {
              final text = _chatController.text;
              if (text.isEmpty) return;

              setModalState(() {
                _messages.add(ChatMessage(text: text, isUser: true));
              });
              _chatController.clear();

              final receivedMessage = await postData(text, _currentLatLng!.latitude, _currentLatLng!.longitude);

              setModalState(() {
                _messages.add(ChatMessage(text: receivedMessage, isUser: false));
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Align(
                            alignment: message.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: message.isUser
                                    ? Colors.blue
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: MarkdownBody(
                                data: message.text,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: message.isUser ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Ask about your route...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                            ),
                            onSubmitted: (_) => handleSendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: handleSendMessage,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629),
              zoom: 5,
            ),
            trafficEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_mapStyle);
            },
            polylines: _polylines,
            markers: _markers.union(_eventMarkers),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          _buildTopUI(),
          // ✨ UPDATED: Replaced _buildEtaCard with a combined info card
          if (_eta != null) _buildInfoCard(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 200.0), // ✨ Adjusted padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_eta != null)
              FloatingActionButton(
                onPressed: _showChatBottomSheet,
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                heroTag: 'chat_fab',
                child: const Icon(Icons.chat_bubble_outline),
              ),
            const SizedBox(height: 16),
            FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              heroTag: 'location_fab',
              child: const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUI() {
    return Positioned(
      top: 50,
      left: 15,
      right: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBarAndDeadline(),
          const SizedBox(height: 8),
          _buildGoalChips(),
          const SizedBox(height: 8),
          if (_suggestions.isNotEmpty) _buildAutocompleteList(),
        ],
      ),
    );
  }

  Widget _buildAutocompleteList() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final s = _suggestions[index];
          return ListTile(
            title: Text(s['description']),
            onTap: () {
              _searchController.text = s['description'];
              setState(() {
                _suggestions = [];
              });
              _searchAndDrawRoute(s['description']);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchBarAndDeadline() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _getAutocomplete(value);
                } else {
                  setState(() {
                    _suggestions = [];
                  });
                }
              },
              onSubmitted: (value) {
                setState(() {
                  _suggestions = [];
                });
                _searchAndDrawRoute(value);
              },
              decoration: InputDecoration(
                hintText: "Search destination",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_deadline != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                avatar: const Icon(Icons.alarm, size: 16),
                label: Text(DateFormat('h:mm a').format(_deadline!)),
                onDeleted: () => setState(() => _deadline = null),
              ),
            ),
          IconButton(
            icon: Icon(Icons.alarm,
                color: _deadline != null ? Colors.blue : Colors.grey),
            onPressed: () => _selectDeadline(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildGoalChips() {
    final goals = ['Commute', 'Explore', 'Errands'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: goals.map((goal) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(goal),
              selected: _selectedGoal == goal,
              onSelected: (selected) {
                setState(() {
                  _selectedGoal = selected ? goal : null;
                });
              },
              selectedColor: Colors.blue[100],
              backgroundColor: Colors.white,
              elevation: 4,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✨ RENAMED & UPDATED: This card now shows summary and ETA
  Widget _buildInfoCard() {
    return Positioned(
      bottom: 30,
      left: 15,
      right: 15,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Section
              if (_isSummaryLoading)
                SizedBox(
                  height: 50,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (!_isSummaryLoading && _routeSummary != null)
                SizedBox(
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SingleChildScrollView(child: MarkdownBody(data: _routeSummary!)),
                  ),
                ),
              if (!_isSummaryLoading && _routeSummary != null) const Divider(),
              // ETA and Distance Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _eta ?? "",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _distance ?? "",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getAutocomplete(String input) async {
    if (_apiKey.isEmpty) return;
    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&location=${_currentLatLng?.latitude},${_currentLatLng?.longitude}&radius=50000";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _suggestions = data["predictions"];
      });
    }
  }

  Future<void> _searchAndDrawRoute(String destination) async {
    setState(() {
      _messages.clear();
      _routeSummary = null; // ✨ Clear previous summary
    });

    if (_currentLatLng == null || destination.isEmpty || _apiKey.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    final startLat = _currentLatLng!.latitude;
    final startLng = _currentLatLng!.longitude;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=$startLat,$startLng&destination=$destination&key=$_apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["routes"].isNotEmpty) {
          final points = _decodePolyline(
              data["routes"][0]["overview_polyline"]["points"]);

          final routePolyline = Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.lightBlue,
            width: 6,
          );

          final leg = data["routes"][0]["legs"][0];
          setState(() {
            _eta = leg["duration"]["text"];
            _distance = leg["distance"]["text"];
            _polylines.clear();
            _polylines.add(routePolyline);
            _markers.clear();
            _markers.add(Marker(
                markerId: const MarkerId("start"),
                position: LatLng(startLat, startLng),
                infoWindow: const InfoWindow(title: "Start")));
            _markers.add(Marker(
                markerId: const MarkerId("end"),
                position: points.last,
                infoWindow: InfoWindow(title: destination)));
          });

          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newLatLngBounds(
              _boundsFromLatLngList(points), 70));

          // ✨ Call for the route summary after drawing the route
          setState(() {
            _isSummaryLoading = true;
          });
          final summary = await getRouteSummary(_currentLatLng!, points.last);
          setState(() {
            _routeSummary = summary;
            _isSummaryLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching directions: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double x0 = list.first.latitude,
        x1 = list.first.latitude,
        y0 = list.first.longitude,
        y1 = list.first.longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(x0, y0), northeast: LatLng(x1, y1));
  }
}