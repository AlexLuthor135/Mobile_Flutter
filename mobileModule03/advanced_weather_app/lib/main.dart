import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

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

  String _weatherCodeToIcon(int code) {
    switch (code) {
      case 0:
        return '☀️';
      case 1:
      case 2:
      case 3:
        return '⛅';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
        return '🌦️';
      case 61:
      case 63:
      case 65:
        return '🌧️';
      case 71:
      case 73:
      case 75:
        return '❄️';
      case 80:
      case 81:
      case 82:
        return '🌦️';
      default:
        return '❓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
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
                Flexible(
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
                            child: SingleChildScrollView(
                            child: Card(
                              color: Colors.white.withAlpha((0.85 * 255).toInt()),
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _displayValue,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _weatherCodeToIcon(_weatherData!['current_weather']['weathercode']),
                                      style: const TextStyle(fontSize: 48),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_weatherData!['current_weather']['temperature']}°C',
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _weatherCodeToString(_weatherData!['current_weather']['weathercode']),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Wind: ${_weatherData!['current_weather']['windspeed']} km/h',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                            : Builder(
                                builder: (context) {
                                  final List temps = (_weatherData!['hourly']['temperature_2m'] as List).take(24).toList();
                                  final double min = temps.reduce((a, b) => a < b ? a : b).toDouble();
                                  final double max = temps.reduce((a, b) => a > b ? a : b).toDouble();
                                  final double mid = ((min + max) / 2);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _displayValue,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 140,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                          child: LineChart(
                                            LineChartData(
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 32,
                                                    interval: (max - min) / 2,
                                                    getTitlesWidget: (value, meta) {
                                                      if ((value - min).abs() < 0.5 ||
                                                          (value - max).abs() < 0.5 ||
                                                          (value - mid).abs() < 0.5) {
                                                        return Text(
                                                          value.toStringAsFixed(0),
                                                          style: const TextStyle(fontSize: 10),
                                                        );
                                                      }
                                                      return const SizedBox.shrink();
                                                    },
                                                  ),
                                                ),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    interval: 4,
                                                    getTitlesWidget: (value, meta) {
                                                      int hour = value.toInt();
                                                      if (hour % 4 == 0 && hour < 24) {
                                                        return Text('$hour', style: const TextStyle(fontSize: 10));
                                                      }
                                                      return const SizedBox.shrink();
                                                    },
                                                  ),
                                                ),
                                              ),
                                              minY: min,
                                              maxY: max,
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: List.generate(
                                                    24,
                                                    (i) => FlSpot(
                                                      i.toDouble(),
                                                      (temps[i] as num).toDouble(),
                                                    ),
                                                  ),
                                                  isCurved: true,
                                                  color: Colors.teal,
                                                  barWidth: 3,
                                                  dotData: FlDotData(show: false),
                                                ),
                                              ],
                                              gridData: FlGridData(show: true),
                                              borderData: FlBorderData(show: false),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: 24,
                                          itemBuilder: (context, i) {
                                            final hourly = _weatherData!['hourly'];
                                            final time = hourly['time'][i].substring(11, 16);
                                            final temp = hourly['temperature_2m'][i];
                                            final code = hourly['weathercode'][i];
                                            final wind = hourly['windspeed_10m'][i];
                                            return ListTile(
                                              leading: Text(
                                                _weatherCodeToIcon(code),
                                                style: const TextStyle(fontSize: 24),
                                              ),
                                              title: Text('$time  |  $temp°C'),
                                              subtitle: Text(
                                                '${_weatherCodeToString(code)}  •  Wind: $wind km/h',
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
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
                    : Builder(
                        builder: (context) {
                          final daily = _weatherData!['daily'];
                          final List minTemps = (daily['temperature_2m_min'] as List).take(7).toList();
                          final List maxTemps = (daily['temperature_2m_max'] as List).take(7).toList();
                          final List codes = (daily['weathercode'] as List).take(7).toList();
                          final List days = (daily['time'] as List).take(7).toList();
                          final double min = minTemps.reduce((a, b) => a < b ? a : b).toDouble();
                          final double max = maxTemps.reduce((a, b) => a > b ? a : b).toDouble();
                          List<String> weekDays = days.map((date) {
                            final dt = DateTime.parse(date);
                            return [
                              'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                            ][dt.weekday - 1];
                          }).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _displayValue,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 140,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: LineChart(
                                    LineChartData(
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 32,
                                            interval: (max - min) / 2,
                                            getTitlesWidget: (value, meta) {
                                              double mid = ((min + max) / 2);
                                              if ((value - min).abs() < 0.5 ||
                                                  (value - max).abs() < 0.5 ||
                                                  (value - mid).abs() < 0.5) {
                                                return Text(
                                                  value.toStringAsFixed(0),
                                                  style: const TextStyle(fontSize: 10),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              int idx = value.toInt();
                                              if (idx >= 0 && idx < weekDays.length) {
                                                return Text(weekDays[idx], style: const TextStyle(fontSize: 10));
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                      ),
                                      minY: min,
                                      maxY: max,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: List.generate(
                                            7,
                                            (i) => FlSpot(i.toDouble(), (minTemps[i] as num).toDouble()),
                                          ),
                                          isCurved: true,
                                          color: Colors.blue,
                                          barWidth: 3,
                                          dotData: FlDotData(show: false),
                                          belowBarData: BarAreaData(show: false),
                                        ),
                                        LineChartBarData(
                                          spots: List.generate(
                                            7,
                                            (i) => FlSpot(i.toDouble(), (maxTemps[i] as num).toDouble()),
                                          ),
                                          isCurved: true,
                                          color: Colors.red,
                                          barWidth: 3,
                                          dotData: FlDotData(show: false),
                                          belowBarData: BarAreaData(show: false),
                                        ),
                                      ],
                                      gridData: FlGridData(show: true),
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: 7,
                                  itemBuilder: (context, i) {
                                    final date = days[i];
                                    final dt = DateTime.parse(date);
                                    final weekDay = [
                                      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
                                    ][dt.weekday - 1];
                                    final minT = minTemps[i];
                                    final maxT = maxTemps[i];
                                    final code = codes[i];
                                    return ListTile(
                                      leading: Text(
                                        _weatherCodeToIcon(code),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      title: Text('$weekDay'),
                                      subtitle: Text(
                                        'Min: $minT°C, Max: $maxT°C • ${_weatherCodeToString(code)}',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
              children: _suggestions.take(5).map((s) => ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold),),
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
