import 'package:flutter/material.dart';

import 'animation_widgets.dart';

class DraggableButton extends StatefulWidget {
  final double size;
  final VoidCallback onTap;
  final FutureController futureController;

  const DraggableButton(
      {Key key, this.size = 40.0, this.onTap, this.futureController})
      : super(key: key);

  @override
  _DraggableButtonState createState() => _DraggableButtonState();
}

class _DraggableButtonState extends State<DraggableButton>
    with SingleTickerProviderStateMixin {
  double _left, _top;
  Size _size;

  AnimationController _controller;
  Animation<double> _animation;
  double _radius = 0;

  @override
  void initState() {
    _left = _savedLeft;
    _top = _savedTop;
    _controller = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1000));
    _animation = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
    widget.futureController?.setCallBack(forward);
    super.initState();
  }

  @override
  void dispose() {
    widget.futureController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future forward() async {
    _radius = 30;
    refresh();
    final result = await _controller.forward();
    _controller.reset();
    _radius = 0;
    refresh();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    _size ??= MediaQuery.of(context).size;
    _left ??= _size.width - 100;
    _top ??= 100;
    return Stack(
      children: [
        Positioned(
          left: this._left,
          top: this._top,
          child: Draggable(
            child: dragWidget(),
            feedback: dragWidget(),
            onDragEnd: onDragEnd,
            childWhenDragging: SizedBox(),
          ),
        )
      ],
    );
  }

  Widget dragWidget() {
    final size = widget.size;
    final circleSize = size - 20 > 10 ? size - 20 : 10;
    final iconSize = circleSize - 8;
    final color = Colors.grey.withOpacity(0.5);
    return GestureDetector(
      onTap: widget.onTap,
      child: WaterRipple(
        waterRadius: _radius,
        animation: _animation,
        count: 5,
        color: color,
        child: Container(
          width: size,
          height: size,
          child: Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _radius > 0 ? Colors.transparent : color,
                  shape: BoxShape.circle,
                ),
              ),
              Center(
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Icon(Icons.bug_report_outlined, size: iconSize, color: Colors.white,),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void onDragEnd(DraggableDetails details) {
    final off = details.offset;
    this._left = off.dx;
    this._top = off.dy;
    _left = this._left;
    _savedLeft = this._left;
    _savedTop = this._top;
    refresh();
    calculateArea();
  }

  void calculateArea() {
    final midW = (_size?.width ?? 0) / 2;
    final midH = (_size?.height ?? 0) / 2;
    if (_top <= midH && _left <= midW) _landingArea = LandingArea.topLeft;
    if (_top > midH && _left <= midW) _landingArea = LandingArea.bottomLeft;
    if (_top <= midH && _left > midW) _landingArea = LandingArea.topRight;
    if (_top > midH && _left > midW) _landingArea = LandingArea.bottomRight;
  }

  void refresh() {
    if (mounted) setState(() {});
  }
}

double _savedLeft, _savedTop;
LandingArea _landingArea = LandingArea.topRight;

Alignment transformLandingArea(LandingArea landingArea) {
  if (landingArea == LandingArea.topRight) return Alignment.topRight;
  if (landingArea == LandingArea.topLeft) return Alignment.topLeft;
  if (landingArea == LandingArea.bottomLeft) return Alignment.bottomLeft;
  return Alignment.bottomRight;
}

Alignment get areaAlign => transformLandingArea(_landingArea);

enum LandingArea { topLeft, topRight, bottomLeft, bottomRight }
