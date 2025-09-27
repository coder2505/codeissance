import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Hardcoded JSON data for the example.
  // In a real app, this would come from an API or database.
  final Map<String, dynamic> _userData = {
    "topFivePreferences": [
      {
        "id": "cafes_and_bistros",
        "name": "Cafes & Bistros",
        "type": "cafe",
        "keywords": ["cafe", "bistro", "coffee shop", "dessert place", "cozy spot"],
        "radius": 2000
      },
      {
        "id": "parks_and_nature",
        "name": "Parks & Nature",
        "type": "park",
        "keywords": ["park", "garden", "nature walk", "green space", "recreation area"],
        "radius": 4000
      },
      {
        "id": "entertainment",
        "name": "Entertainment",
        "type": "movie_theater",
        "keywords": ["cinema", "movie theater", "arcade", "bowling", "live shows"],
        "radius": 5000
      },
      {
        "id": "shopping_and_malls",
        "name": "Shopping & Malls",
        "type": "shopping_mall",
        "keywords": ["mall", "shopping center", "boutique", "market", "arcade"],
        "radius": 3000
      },
      {
        "id": "sports_and_fitness",
        "name": "Sports & Fitness",
        "type": "gym",
        "keywords": ["gym", "fitness center", "yoga studio", "swimming pool", "sports complex"],
        "radius": 3500
      }
    ],
    "settings": {
      "maxResultsPerType": 10.0, // Use double for slider
      "defaultRadius": 5000.0, // Use double for slider
      "units": "meters"
    }
  };

  // State variables for interactive elements
  late Map<String, bool> _preferencesEnabled;
  late double _maxResults;
  late double _defaultRadius;

  @override
  void initState() {
    super.initState();
    // Initialize the state from the user data
    _preferencesEnabled = {
      for (var pref in _userData['topFivePreferences']) pref['id']: true
    };
    _maxResults = _userData['settings']['maxResultsPerType'];
    _defaultRadius = _userData['settings']['defaultRadius'];
  }

  // Helper function to get an icon based on preference type
  IconData _getIconForPreference(String type) {
    switch (type) {
      case 'cafe':
        return Icons.coffee_outlined;
      case 'park':
        return Icons.park_outlined;
      case 'movie_theater':
        return Icons.theaters_outlined;
      case 'shopping_mall':
        return Icons.shopping_bag_outlined;
      case 'gym':
        return Icons.fitness_center_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildPreferencesList(),
          const SizedBox(height: 24),
          _buildSettingsSection(),
        ],
      ),
    );
  }

  // Widget for the user profile header
  Widget _buildProfileHeader() {
    return const Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150'), // Placeholder image
          backgroundColor: Colors.grey,
        ),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aryan Pathak', // Placeholder name
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'aryan.p@example.com', // Placeholder email
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  // Widget for the list of user preferences
  Widget _buildPreferencesList() {
    final preferences = _userData['topFivePreferences'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Preferences',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...preferences.map((pref) {
          final String id = pref['id'];
          final String name = pref['name'];
          final String type = pref['type'];
          final int radius = pref['radius'];
          final keywords = pref['keywords'] as List;

          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(_getIconForPreference(type), color: Colors.blueAccent),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Search Radius: ${radius}m'),
                    trailing: Switch(
                      value: _preferencesEnabled[id] ?? true,
                      onChanged: (bool value) {
                        setState(() {
                          _preferencesEnabled[id] = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: keywords.map((keyword) => Chip(
                        label: Text(keyword),
                        backgroundColor: Colors.blue.shade50,
                        side: BorderSide(color: Colors.blue.shade100),
                        labelStyle: TextStyle(color: Colors.blue.shade800),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  // Widget for the general settings section
  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'General Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Max Results per Category: ${_maxResults.toInt()}'),
                subtitle: Slider(
                  value: _maxResults,
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: _maxResults.round().toString(),
                  onChanged: (double value) {
                    setState(() {
                      _maxResults = value;
                    });
                  },
                ),
              ),
              ListTile(
                title: Text('Default Search Radius: ${_defaultRadius.toInt()}m'),
                subtitle: Slider(
                  value: _defaultRadius,
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  label: '${_defaultRadius.round()}m',
                  onChanged: (double value) {
                    setState(() {
                      _defaultRadius = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}