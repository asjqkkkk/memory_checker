import 'dart:math';

import 'package:flutter/material.dart';

import 'draggable_button.dart';

class WaterRipple extends StatelessWidget {
  final int count;
  final Color color;
  final Widget child;
  final double waterRadius;
  final Animation animation;

  const WaterRipple(
      {Key key,
      this.count = 3,
      this.color = const Color(0xff91959B),
      @required this.animation,
      this.child,
      this.waterRadius = 30})
      : super(key: key);


  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: WaterRipplePainter(animation.value,
              count: count,
              color: color,
              waterRadius: waterRadius),
          child: this.child ?? SizedBox(),
        );
      },
    );
  }


}

class WaterRipplePainter extends CustomPainter {
  final double progress;
  final int count;
  final Color color;
  final double waterRadius;
  Paint _paint = Paint()..style = PaintingStyle.fill;

  WaterRipplePainter(this.progress,
      {this.count = 3,
      this.color = const Color(0xff101010),
      this.waterRadius = 30});

  @override
  void paint(Canvas canvas, Size size) {
    double radius = min(size.width / 2, size.height / 2);
    for (int i = count; i >= 0; i--) {
      final double opacity = (1.0 - ((i + progress) / (count + 1)));
      final Color _color = color.withOpacity(opacity);
      _paint..color = _color;
      double _radius = (radius + waterRadius) * ((i + progress) / (count + 1));
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), waterRadius == 0 ? 0 : _radius, _paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class ScaleAniWidget extends StatefulWidget {
  final Widget child;
  final FutureController futureController;

  const ScaleAniWidget({Key key, @required this.child, this.futureController})
      : super(key: key);

  @override
  _ScaleAniWidgetState createState() => _ScaleAniWidgetState();
}

class _ScaleAniWidgetState extends State<ScaleAniWidget>
    with SingleTickerProviderStateMixin {
  Animation<double> animation;
  AnimationController controller;

  @override
  initState() {
    controller =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this);
    animation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutSine));
    //启动动画(正向执行)
    controller.forward();
    widget.futureController?._futureCallback = reverse;
    super.initState();
  }

  @override
  void dispose() {
    widget.futureController?._futureCallback = null;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (ctx, child) => Transform.scale(
        scale: animation.value,
        child: child,
        alignment: areaAlign,
      ),
    );
  }

  Future reverse() async {
    await controller.reverse();
  }
}

class FutureController {
  AsyncCallback _futureCallback;

  Future onCall() async {
    return _futureCallback?.call();
  }

  void setCallBack(AsyncCallback callback){
    if(_futureCallback == null && callback != null) _futureCallback = callback;
  }

  void dispose() => this._futureCallback = null;
}

typedef AsyncCallback = Future Function();
