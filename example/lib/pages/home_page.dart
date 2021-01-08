import 'package:flutter/material.dart';

import 'all_pages.dart';
import 'all_pages.dart';
import 'all_pages.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Widget> pages = [
    PageOne(),
    PageTwo(),
    PageThree(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Memory Checker'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (index) {
              final page = pages[index];
              return FlatButton(
                  onPressed: () => Navigator.of(context)
                      .push(new MaterialPageRoute(builder: (ctx) => page)),
                  child: Text(page.toString()));
            }),
          ),
        ),
      ),
    );
  }
}
