import 'package:flutter/material.dart';

void main() => runApp(Ex01App());

class Ex01App extends StatefulWidget {
  const Ex01App({super.key});
  @override
  Ex01AppState createState() => Ex01AppState();
}

class Ex01AppState extends State<Ex01App> {
  bool _showHello = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _showHello ? 'Hello World!' : 'Welcome!',
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showHello = !_showHello;
                  });
                },
                child: Text('Toggle Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
