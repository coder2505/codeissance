import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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

  // --- TODO: Add your Google Maps API key here ---
  final String _apiKey = "AIzaSyBAvUgw3DsmwlzJUXHQ693ClGK7jpsh4Fg";

  // A custom dark map style
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    // Load the custom map style from assets
    rootBundle.loadString('assets/map_style.json').then((string) {
      _mapStyle = string;
    });
    _determinePosition();
  }

  /// Fetches the user's current location and animates the camera.
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle service not enabled
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle permission denied
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle permission permanently denied
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });

    _goToCurrentLocation();
  }

  /// Animates the map to the user's current location.
  Future<void> _goToCurrentLocation() async {
    if (_currentLatLng == null) return;
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng!, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629), // Default to India center
              zoom: 5,
            ),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              // Apply the custom map style
              controller.setMapStyle(_mapStyle);
            },
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We have a custom button
            zoomControlsEnabled: false,
          ),
          _buildSearchBar(),
          if (_eta != null && _distance != null) _buildEtaCard(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75.0),
        child: FloatingActionButton(
          onPressed: _goToCurrentLocation,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  /// Builds the floating search bar and autocomplete suggestions.
  Widget _buildSearchBar() {
    return Positioned(
      top: 50,
      left: 15,
      right: 15,
      child: Column(
        children: [
          Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(30),
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
                _searchAndDrawRoute(value);
                setState(() {
                  _suggestions = [];
                });
              },
              decoration: InputDecoration(
                hintText: "Search destination",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions = [];
                      _polylines.clear();
                      _markers.clear();
                      _eta = null;
                      _distance = null;
                    });
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    title: Text(s['description']),
                    onTap: () {
                      _searchController.text = s['description'];
                      _searchAndDrawRoute(s['description']);
                      setState(() {
                        _suggestions = [];
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the card displaying ETA and distance.
  Widget _buildEtaCard() {
    return Positioned(
      bottom: 30,
      left: 15,
      right: 15,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
        ),
      ),
    );
  }

  /// Fetches place autocomplete suggestions from Google Places API.
  Future<void> _getAutocomplete(String input) async {
    if (_apiKey.isEmpty) return;
    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _suggestions = data["predictions"];
      });
    }
  }

  /// Fetches directions and draws the route on the map.
  Future<void> _searchAndDrawRoute(String destination) async {
    if (_currentLatLng == null || destination.isEmpty || _apiKey.isEmpty) return;

    FocusScope.of(context).unfocus(); // Hide keyboard
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
        }
      }
    } catch (e) {
      // Handle error
      print("Error fetching directions: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Utility Functions (unchanged) ---

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