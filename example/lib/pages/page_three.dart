import 'package:flutter/material.dart';

class PageThree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('This leak was caused by flutter, but it will be released finally', style: TextStyle(fontSize: 18),),
      ),
    );
  }
}
