import 'package:flutter/material.dart';

class PageTwo extends StatefulWidget {
  @override
  _PageTwoState createState() => _PageTwoState();
}

class _PageTwoState extends State<PageTwo> {

  @override
  Widget build(BuildContext context) {
    _anotherTestForLeak._stateList.add(this);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text('Another Test For Leak', style: TextStyle(fontSize: 18),),
      ),
    );
  }
}

AnotherTestForLeak _anotherTestForLeak = AnotherTestForLeak();

class AnotherTestForLeak{
  Set<State> _stateList = {};
}
