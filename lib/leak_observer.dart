import 'package:flutter/material.dart';

import 'checker_util.dart';

class LeakObserver extends NavigatorObserver {

  final Set<TargetWidget> extraCheckTargets;

  final Set<TargetWidget> filterCheckTargets;

  LeakObserver({this.extraCheckTargets, this.filterCheckTargets});

  @override
  void didPop(Route<dynamic> route, Route<dynamic> previousRoute) => _doCheck(route, previousRoute);


  @override
  void didReplace({Route<dynamic> newRoute, Route<dynamic> oldRoute}) => _doCheck(newRoute, oldRoute);


  @override
  void didRemove(Route<dynamic> route, Route<dynamic> previousRoute) => _doCheck(route, previousRoute);

  Future<bool> get enableCheck => Future.value(true);

  void _doCheck(Route<dynamic> route, Route<dynamic> previousRoute) async{
    final enableCheck = await this.enableCheck;
    if(!enableCheck) return;
    doCheck(route, previousRoute, navigator, extraCheckTargets: extraCheckTargets, filterCheckTargets: filterCheckTargets);
  }
}
