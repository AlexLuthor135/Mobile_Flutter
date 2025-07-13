import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

void main() => runApp(Ex03App());

class Ex03App extends StatefulWidget {
  const Ex03App({super.key});
  @override
  Ex03AppState createState() => Ex03AppState();
}

class Ex03AppState extends State<Ex03App> {
  final List<String> buttons = [
    'AC', 'C', '/', '*',
    '7', '8', '9', '-',
    '4', '5', '6', '+',
    '1', '2', '3', '=',
    '0', '.',
  ];
  String result = '0';
  String expression = '';
  final TextEditingController expressionController = TextEditingController();
  final TextEditingController resultController = TextEditingController();

  void _onPressed(String text){
    setState(() {
      if (text == 'AC') {
          expression = '';
          result = '0';
      }
      else if (text == '=') {
        try {
            Expression exp = GrammarParser().parse(expression);
            ContextModel cm = ContextModel();
            double eval = exp.evaluate(EvaluationType.REAL, cm);
            if (eval == eval.toInt()) {
              result = eval.toInt().toString();
            }
            else {
              result = eval.toString();
            }
        }
        catch (e) {
            result = 'Error';
        }
      }
      else if (text == 'C') {
        if (expression.isNotEmpty) {
          expression = expression.substring(0, expression.length - 1);
        }
      }
      else {
          expression += text;
      }
      expressionController.text = expression;
      resultController.text = result;
    });
  }
  @override
  void initState() {
    super.initState();
    expressionController.text = expression;
    resultController.text = result;
  }

  @override
  void dispose () {
    expressionController.dispose();
    resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Calculator')),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                readOnly: true,
                controller: expressionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '0',
                  labelText: 'Expression',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                readOnly: true,
                controller: resultController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '0',
                  labelText: 'Result',
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4
                  ),
                  itemCount: buttons.length,
                  itemBuilder: (context, index) {
                    return ElevatedButton(
                        onPressed: () => _onPressed(buttons[index]),
                        child: Text(
                          buttons[index],
                          style: TextStyle(fontSize: 20),
                        )
                    );
                  }
              ),
            )
          ],
        ),
      ),
    );
  }
}