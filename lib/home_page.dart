import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _kPortNameOverlay = 'OVERLAY';
  static const String _kPortNameHome = 'UI';
  final _receivePort = ReceivePort();
  SendPort? homePort;
  String? latestMessageFromOverlay;

  @override
  void initState() {
    super.initState();
    if (homePort != null) return;
    final res = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _kPortNameHome,
    );
    log("$res: OVERLAY");
    _receivePort.listen((message) {
      log("message from OVERLAY: $message");
      setState(() {
        latestMessageFromOverlay = 'Latest Message From Overlay: $message';
      });
    });
    Permission.microphone.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bubble wise settings'),
        backgroundColor: Colors.grey[350]!,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[300]!, Colors.grey[500]!],
          ),
        ),
        child: Center(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 20.0,
            crossAxisSpacing: 20.0,
            padding: EdgeInsets.all(20.0),
            children: [
              ElevatedButton(
                onPressed: () async {
                  final bool? res =
                      await FlutterOverlayWindow.requestPermission();
                  print("Permission requested: $res");
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue, // Color del fondo del botón
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15.0), // Bordes redondeados
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                  textStyle: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 5, // Elevación para la sombra
                  shadowColor: Colors.black, // Color de la sombra
                ),
                child: const Text(
                  "Request Permission",
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (await FlutterOverlayWindow.isActive()) return;
                  await FlutterOverlayWindow.showOverlay(
                    enableDrag: true,
                    overlayTitle: "Bubble wise",
                    overlayContent: 'Enabled',
                    flag: OverlayFlag.defaultFlag,
                    visibility: NotificationVisibility.visibilityPublic,
                    positionGravity: PositionGravity.auto,
                    height: (MediaQuery.of(context).size.height * 1.6).toInt(),
                    width: WindowSize.matchParent,
                    startPosition: const OverlayPosition(0, 0),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green, // Color del fondo del botón
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15.0), // Bordes redondeados
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                  textStyle: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 5, // Elevación para la sombra
                  shadowColor: Colors.black, // Color de la sombra
                ),
                child: const Text(
                  "Show Overlay",
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  print('Try to close');
                  FlutterOverlayWindow.closeOverlay()
                      .then((value) => print('Overlay closed: $value'));
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red, // Color del fondo del botón
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15.0), // Bordes redondeados
                  ),
                  padding:
                      EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                  textStyle: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 5, // Elevación para la sombra
                  shadowColor: Colors.black, // Color de la sombra
                ),
                child: const Text(
                  "Close Overlay",
                  textAlign: TextAlign.center,
                ),
              ),
              // Espacio para el cuarto botón o ajustes adicionales
            ],
          ),
        ),
      ),
    );
  }
}
