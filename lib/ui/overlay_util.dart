import 'package:flutter/material.dart';

class OverlayUtil {
  static OverlayUtil _instance;

  static OverlayUtil getInstance() {
    if (_instance == null) {
      _instance = OverlayUtil._internal();
    }
    return _instance;
  }

  OverlayUtil._internal();

  OverlayEntry _overlayEntry;

  void show(
      {Widget showWidget,
      OverlayState overlayState,
      BuildContext context,
      String text = "默认显示内容",
      Duration duration}) {
    if (_overlayEntry == null) {
      _showEntry(showWidget, text, duration,
          context: context, overlayState: overlayState);
    }
  }

  void reshow(OverlayState overlayState) {
    if (_overlayEntry == null) return;
    overlayState.insert(_overlayEntry);
  }

  void hide() {
    if (_overlayEntry != null) {
      _overlayEntry.remove();
    }
  }

  void _showEntry(Widget showWidget, String text, Duration duration,
      {OverlayState overlayState, BuildContext context}) {
    assert(overlayState != null || context != null);
    _overlayEntry = OverlayEntry(builder: (ctx) {
      return showWidget ?? _defaultShow(text);
    });
    (overlayState ?? Overlay.of(context)).insert(_overlayEntry);
  }

  Widget _defaultShow(String text) {
    return Container(
      alignment: Alignment.bottomCenter,
      margin: EdgeInsets.only(bottom: 50),
      child: Material(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        color: Colors.grey.withOpacity(0.5),
        child: Container(
          margin: EdgeInsets.fromLTRB(10, 5, 10, 5),
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
