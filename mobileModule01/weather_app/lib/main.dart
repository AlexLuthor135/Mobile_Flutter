import 'package:flutter/material.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _displayValue = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    setState(() {
      _displayValue = value;
    });
  }

  void _onGeoPressed() {
    setState(() {
      _displayValue = 'Geolocation';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: SearchBar(
            controller: _searchController,
            onSubmitted: _onSearchSubmitted,
          ),
          backgroundColor: Colors.teal,
          elevation: 0,
          leading: IconButton(onPressed: () => _onSearchSubmitted(_searchController.text),
          icon: Icon(Icons.search)
          ),
          actions: [
            IconButton(
              onPressed: _onGeoPressed,
              icon: Icon(Icons.location_on, color: Colors.white),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            Center(child: Text('Currently: ${_displayValue.isEmpty ? "" : _displayValue}')),
          Center(child: Text('Today: ${_displayValue.isEmpty ? "" : _displayValue}')),
          Center(child: Text('Weekly: ${_displayValue.isEmpty ? "" : _displayValue}')),
          ]
        ),
        bottomNavigationBar: BottomAppBar(
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.access_time), text: 'Currently',),
              Tab(icon: Icon(Icons.today), text: 'Today'),
              Tab(icon: Icon(Icons.calendar_today), text: 'Weekly'),
            ]
          )
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSubmitted,
    });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search location...',
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
