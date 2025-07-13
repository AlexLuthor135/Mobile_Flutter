import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 0,
);

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherHome(),
    );
  }
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _displayValue = '';
  String _locationError = '';
  String _searchError = '';
  Map<String, dynamic>? _weatherData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onGeoPressed() {
    _getLocation();
  }

  Future<String> _getCityNameFromCoords(double lat, double lon) async {
    final url = Uri.parse('https://geocode.maps.co/reverse?lat=$lat&lon=$lon');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? '';
        final state = address['state'] ?? '';
        final country = address['country'] ?? '';
        if (city.isNotEmpty) {
          return '$city, $state, $country';
        }
      }
    } on TimeoutException {
      setState(() {
        _locationError = 'Reverse geocoding timed out.';
      });
    } catch (e) {
      setState(() {
        _locationError = 'Reverse geocoding error.';
      });
    }
    return 'Lat: $lat, Lon: $lon';
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are unavailable';
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission permanently denied.';
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      final cityName = await _getCityNameFromCoords(position.latitude, position.longitude);
      setState(() {
        _displayValue = cityName;
        _locationError = '';
        _searchError = '';
      });
      await _fetchWeather(position.latitude, position.longitude, cityName);
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _fetchWeather(double lat, double lon, String locationString) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
      '&current_weather=true'
      '&hourly=temperature_2m,weathercode,windspeed_10m'
      '&daily=temperature_2m_max,temperature_2m_min,weathercode'
      '&timezone=auto'
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherData = data;
          _displayValue = locationString;
          _locationError = '';
          _searchError = '';
        });
      } else {
        setState(() {
          _weatherData = null;
          _locationError = 'Failed to fetch weather data';
        });
      }
    } on TimeoutException {
      setState(() {
        _weatherData = null;
        _locationError = 'Weather API timed out.';
      });
    } catch (e) {
      setState(() {
        _weatherData = null;
        _locationError = 'Failed to fetch weather data: $e';
      });
    }
  }

  String _weatherCodeToString(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Mainly clear, partly cloudy, overcast';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _onGeoPressed,
            icon: const Icon(Icons.location_on, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_searchError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _searchError,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            SearchBarWithSuggestions(
              showSuggestions: true,
              onCitySelected: (city) {
                setState(() {
                  _displayValue = '${city.name}, ${city.region}, ${city.country}';
                  _locationError = '';
                  _searchError = '';
                });
                _fetchWeather(city.latitude, city.longitude, '${city.name}, ${city.region}, ${city.country}');
              },
              onError: (String error) {
                setState(() {
                  _searchError = error;
                });
              },
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _locationError.isNotEmpty
                      ? Center(
                          child: Text(
                            _locationError,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : _weatherData == null
                          ? const Center(child: Text('No data'))
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_displayValue, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('Temperature: ${_weatherData!['current_weather']['temperature']}°C'),
                                  Text('Weather: ${_weatherCodeToString(_weatherData!['current_weather']['weathercode'])}'),
                                  Text('Wind: ${_weatherData!['current_weather']['windspeed']} km/h'),
                                ],
                              ),
                            ),
                  _locationError.isNotEmpty
                      ? Center(
                          child: Text(
                            _locationError,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : _weatherData == null
                          ? const Center(child: Text('No data'))
                          : Column(
                              children: [
                                Text(_displayValue, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: 24,
                                    itemBuilder: (context, i) {
                                      final hourly = _weatherData!['hourly'];
                                      return ListTile(
                                        title: Text(hourly['time'][i]),
                                        subtitle: Text(
                                          'Temp: ${hourly['temperature_2m'][i]}°C, '
                                          'Weather: ${_weatherCodeToString(hourly['weathercode'][i])}, '
                                          'Wind: ${hourly['windspeed_10m'][i]} km/h',
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                  _locationError.isNotEmpty
                      ? Center(
                          child: Text(
                            _locationError,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : _weatherData == null
                          ? const Center(child: Text('No data'))
                          : Column(
                              children: [
                                Text(_displayValue, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _weatherData!['daily']['time'].length,
                                    itemBuilder: (context, i) {
                                      final daily = _weatherData!['daily'];
                                      return ListTile(
                                        title: Text(daily['time'][i]),
                                        subtitle: Text(
                                          'Min: ${daily['temperature_2m_min'][i]}°C, '
                                          'Max: ${daily['temperature_2m_max'][i]}°C, '
                                          'Weather: ${_weatherCodeToString(daily['weathercode'][i])}',
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: 'Currently'),
            Tab(icon: Icon(Icons.today), text: 'Today'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Weekly'),
          ],
        ),
      ),
    );
  }
}

class CitySuggestion {
  final String name;
  final String country;
  final String region;
  final double latitude;
  final double longitude;

  CitySuggestion({
    required this.name,
    required this.country,
    required this.region,
    required this.latitude,
    required this.longitude,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      region: json['admin1'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
    );
  }
}

class SearchBarWithSuggestions extends StatefulWidget {
  final Function(CitySuggestion) onCitySelected;
  final bool showSuggestions;
  final Function(String)? onError;

  const SearchBarWithSuggestions({
    super.key,
    required this.onCitySelected,
    this.showSuggestions = true,
    this.onError,
  });

  @override
  State<SearchBarWithSuggestions> createState() => _SearchBarWithSuggestionsState();
}

class _SearchBarWithSuggestionsState extends State<SearchBarWithSuggestions> {
  final TextEditingController _controller = TextEditingController();
  List<CitySuggestion> _suggestions = [];
  bool _isLoading = false;

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      if (widget.onError != null) widget.onError!('');
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$query');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final results = json['results'] as List?;
        if (results != null && results.isNotEmpty) {
          setState(() {
            _suggestions = results.map((e) => CitySuggestion.fromJson(e)).toList();
          });
          if (widget.onError != null) widget.onError!('');
        } else {
          setState(() => _suggestions = []);
          if (widget.onError != null) widget.onError!('City not found.');
        }
      } else {
        setState(() => _suggestions = []);
        if (widget.onError != null) widget.onError!('Connection error.');
      }
    } on TimeoutException {
      setState(() => _suggestions = []);
      if (widget.onError != null) widget.onError!('Connection timed out.');
    } catch (e) {
      setState(() => _suggestions = []);
      if (widget.onError != null) widget.onError!('Connection error.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _fetchSuggestions,
            decoration: const InputDecoration(
              hintText: 'Search location...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        if (_isLoading)
          const LinearProgressIndicator(),
        if (_suggestions.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView(
              shrinkWrap: true,
              children: _suggestions.map((s) => ListTile(
                title: Text(s.name),
                subtitle: Text('${s.region}, ${s.country}'),
                onTap: () {
                  widget.onCitySelected(s);
                  if (widget.onError != null) widget.onError!('');
                  setState(() {
                    _controller.text = s.name;
                    _suggestions = [];
                  });
                },
              )).toList(),
            ),
          ),
      ],
    );
  }
}
