import 'dart:developer';

import 'package:bubble_wise/fly_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class TrueCallerOverlay extends StatefulWidget {
  const TrueCallerOverlay({Key? key}) : super(key: key);

  @override
  State<TrueCallerOverlay> createState() => _TrueCallerOverlayState();
}

class _TrueCallerOverlayState extends State<TrueCallerOverlay> {
  bool isGold = true;

  final _goldColors = const [
    Color(0xFFa2790d),
    Color(0xFFebd197),
    Color(0xFFa2790d),
  ];

  final _silverColors = const [
    Color(0xFFAEB2B8),
    Color(0xFFC7C9CB),
    Color(0xFFD7D7D8),
    Color(0xFFAEB2B8),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGold ? _goldColors : _silverColors,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                isGold = !isGold;
              });
              FlutterOverlayWindow.getOverlayPosition().then((value) {
                log("Overlay Position: $value");
              });
            },
            child: const SpeechSampleApp(),
          ),
        ),
      ),
    );
  }
}
