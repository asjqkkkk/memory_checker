import 'package:flutter/material.dart';

import 'checker_util.dart';

class LeakObserver extends NavigatorObserver {

  final Set<String> extraCheckTargets;

  final Set<String> filterCheckTargets;

  LeakObserver({this.extraCheckTargets, this.filterCheckTargets});

  @override
  void didPop(Route<dynamic> route, Route<dynamic> previousRoute) => doCheck(route, previousRoute);


  @override
  void didReplace({Route<dynamic> newRoute, Route<dynamic> oldRoute}) => doCheck(newRoute, oldRoute);


  @override
  void didRemove(Route<dynamic> route, Route<dynamic> previousRoute) => doCheck(route, previousRoute);

}