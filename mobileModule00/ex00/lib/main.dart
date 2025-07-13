import 'package:flutter/material.dart';

void main() => runApp(Ex00App());

class Ex00App extends StatelessWidget {
  const Ex00App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Welcome!'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  debugPrint('Button pressed');
                },
                child: Text('Press me'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
