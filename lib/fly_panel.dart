import 'dart:async';
import 'dart:io';

import 'package:bubble_wise/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'dart:math';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

class SpeechSampleApp extends StatefulWidget {
  const SpeechSampleApp({Key? key}) : super(key: key);

  @override
  State<SpeechSampleApp> createState() => _SpeechSampleAppState();
}

/// An example that demonstrates the basic functionality of the
/// SpeechToText plugin for using the speech recognition capability
/// of the underlying platform.
class _SpeechSampleAppState extends State<SpeechSampleApp> {
  bool _hasSpeech = false;
  bool _logEvents = false;
  bool _onDevice = false;
  bool _speechEnabled = false;
  bool _stopUser = false;
  bool _speechAvailable = false;
  String _currentWords = '';
  String _auxCurrentWords = '';
  String _lastWords = '';
  final TextEditingController _pauseForController =
      TextEditingController(text: '3');
  final TextEditingController _listenForController =
      TextEditingController(text: '30');
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();
  RingerModeStatus _soundMode = RingerModeStatus.unknown;
  String? _permissionStatus;

  final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
          temperature: 0.9,
          topK: 64,
          topP: 0.95,
          maxOutputTokens: 2048,
          responseMimeType: "text/plain"));

  @override
  void initState() {
    super.initState();
    _getCurrentSoundMode();
    _getPermissionStatus();
    _setVibrateMode();
    checkPermanentlyDenied();
  }

  /// This initializes SpeechToText. That only has to be done
  /// once per application, though calling it again is harmless
  /// it also does nothing. The UX of the sample app ensures that
  /// it can only be called once.
  Future<void> initSpeechState() async {
    _logEvent('Initialize');
    try {
      var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: _logEvents,
      );
      if (hasSpeech) {
        // Get the list of languages installed on the supporting platform so they
        // can be displayed in the UI for selection by the user.
        _localeNames = await speech.locales();

        var systemLocale = await speech.systemLocale();
        _currentLocaleId = systemLocale?.localeId ?? '';
      }
      if (!mounted) return;

      setState(() {
        _hasSpeech = hasSpeech;
      });
    } catch (e) {
      setState(() {
        lastError = 'Speech recognition failed: ${e.toString()}';
        _hasSpeech = false;
      });
    }
  }

  Future<void> _getCurrentSoundMode() async {
    RingerModeStatus ringerStatus = RingerModeStatus.unknown;

    Future.delayed(const Duration(seconds: 1), () async {
      try {
        ringerStatus = await SoundMode.ringerModeStatus;
        print(ringerStatus);
      } catch (err) {
        ringerStatus = RingerModeStatus.unknown;
      }

      setState(() {
        _soundMode = ringerStatus;
      });
    });
  }

  Future<void> _getPermissionStatus() async {
    bool? permissionStatus = false;
    try {
      permissionStatus = await PermissionHandler.permissionsGranted;
      print(permissionStatus);
    } catch (err) {
      print(err);
    }

    setState(() {
      _permissionStatus =
          permissionStatus! ? "Permissions Enabled" : "Permissions not granted";
    });
  }

  Future<bool> checkPermanentlyDenied() async {
    final permission = Permission.camera;

    return await permission.status.isPermanentlyDenied;
  }

  Future<void> _setVibrateMode() async {
    RingerModeStatus status;

    try {
      status = await SoundMode.setSoundMode(RingerModeStatus.vibrate);

      setState(() {
        _soundMode = status;
      });
    } on PlatformException {
      print('Do Not Disturb access permissions required!');
    }
  }

  Future<void> _openDoNotDisturbSettings() async {
    await PermissionHandler.openDoNotDisturbSetting();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Bubble wise'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                stopListening();
                FlutterOverlayWindow.closeOverlay()
                    .then((value) => log('STOPPED: alue: $value' as num));
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const HeaderWidget(),
              Column(
                children: <Widget>[
                  InitSpeechWidget(_hasSpeech, initSpeechState),
                  SpeechControlWidget(
                    _hasSpeech,
                    speech.isListening,
                    startListening,
                    stopListening,
                    cancelListening,
                  ),
                  SessionOptionsWidget(
                    _currentLocaleId,
                    _switchLang,
                    _localeNames,
                    _logEvents,
                    _switchLogging,
                    _pauseForController,
                    _listenForController,
                    _onDevice,
                    _switchOnDevice,
                  ),
                ],
              ),
              SizedBox(
                height: 400, // Adjust the height as needed
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: RecognitionResultsWidget(
                        lastWords: _lastWords,
                        level: level,
                        currentWords: _currentWords,
                        speechAvailable: _speechAvailable,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: ErrorWidget(lastError: lastError),
                    ),
                  ],
                ),
              ),
              SpeechStatusWidget(speech: speech),
            ],
          ),
        ),
      ),
    );
  }

  // This is called each time the users wants to start a new speech
  // recognition session
  Future startListening() async {
    _logEvent('start listening');
    _stopUser = false;
    await _stopListening();
    await Future.delayed(const Duration(milliseconds: 50));

    final pauseFor = int.tryParse(_pauseForController.text);
    final listenFor = int.tryParse(_listenForController.text);
    final options = SpeechListenOptions(
        onDevice: _onDevice,
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
        autoPunctuation: true,
        enableHapticFeedback: true);
    // Note that `listenFor` is the maximum, not the minimum, on some
    // systems recognition will be stopped before this value is reached.
    // Similarly `pauseFor` is a maximum not a minimum and may be ignored
    // on some devices.
    speech.listen(
      onResult: resultListener,
      localeId: _currentLocaleId,
      onSoundLevelChange: soundLevelListener,
      listenOptions: options,
    );
    setState(() {
      _speechEnabled = true;
    });
  }

  Future<List<String>> _geminiAPI(String currentWords) async {
    // final prompt = TextPart(
    //   "You will receive two elements: the initials of the country and the language in which you will be working after the & symbol, and a sentence after the % symbol. Your task is to indicate if the sentence is grammatically correct. Punctuation marks do not count. Respond with [true] if the sentence is gramatically correct,  [false] if it is not and [almost] if it's gramaticaly correct but you can use another natural or better way to say that. If the sentence is incorrect, just provide an improved example of that sentence. If you do not receive anything after the %, do not make any corrections:" +
    //       '& ' +
    //       _currentLocaleId +
    //       '% ' +
    //       currentWords,
    // );
    // Initialize the chat
    final chat = model.startChat(history: [
      Content.model([
        TextPart(
          "You will receive two elements: the initials of the country and the language in which you will be working after the & symbol, and a sentence after the % symbol. Your task is to indicate if the sentence is grammatically and contextually correct. Punctuation marks do not count. Respond with [true] if the sentence is gramatically correct,  [false] if it is not and [almost] if it's gramaticaly correct but you can use another natural or better way to say that, after every [] you will do a give the alternative sentence in a new line. If the sentence is incorrect, just provide an improved example of that sentence. If sentence is correct, just provided an another way to say. If you do not receive anything after the %, do not make any corrections:" +
              '& ' +
              _currentLocaleId +
              '% ' +
              currentWords,
        )
      ])
    ]);
    // final response = await model.generateContent([
    //   Content.multi([prompt]),
    // ]);
    var content = Content.text(currentWords);
    var response2 = await chat.sendMessage(content);
    // String responseAux = response.text ?? '';
    print(_auxCurrentWords);
    final RegExp regex = RegExp(r'\[(true|false)\]');
    final match = regex.firstMatch(response2.text ?? '')?.group(0) ?? '';

    return [match, response2.text ?? ''];
  }

  void _geminiAPIInitialize() async {
    final prompt = TextPart("");
  }

  Future _stopListening() async {
    setState(() {
      _speechEnabled = false;
    });
    await speech.stop();
  }

  void stopListening() {
    _logEvent('stop');
    speech.stop();

    setState(() {
      level = 0.0;
      _stopUser = true;
      print(_stopUser);
    });
  }

  void cancelListening() {
    _logEvent('cancel');
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  /// This callback is invoked each time new recognition results are
  /// available after `listen` is called.
  void resultListener(SpeechRecognitionResult result) {
    _logEvent(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
    setState(() {
      _currentWords = result.recognizedWords;
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) async {
    _logEvent(
        'Received error status: $error, listening: ${speech.isListening}');
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
    if (error.errorMsg == 'error_no_match' &&
        _speechEnabled &&
        _stopUser == false) {
      setState(() {
        _lastWords += " $_currentWords";
        _currentWords = "";
        _speechEnabled = false;
      });
      await startListening();
    }
  }

  void statusListener(String status) async {
    String validatorResponse = '';

    String match = '';
    String responseText = '';
    bool apiResponse = false;
    _logEvent(
        'Received listener status: $status, listening: ${speech.isListening}');
    debugPrint("status $status");
    if (status == "done" && _speechEnabled && _stopUser == false) {
      setState(() {
        _auxCurrentWords = " $_currentWords";
        _lastWords += " $_currentWords";

        _currentWords = "";
        _speechEnabled = false;
      });
      //await _geminiAPI(_auxCurrentWords);
      // Mostrar el diálogo mientras se ejecuta la función _geminiAPI
// Mostrar el diálogo
      // Esperar 3 segundos y cerrar el diálogo
      try {
        List<String> response = await _geminiAPI(_auxCurrentWords);
        match = response[0];
        responseText = response[1];
        apiResponse = match == '[true]';
      } finally {}
      await showDialog(
        context: context,
        barrierDismissible:
            false, // Evita que el usuario cierre el diálogo al tocar fuera de él
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            apiResponse ? Icons.check_circle : Icons.cancel,
                            color: apiResponse ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 10),
                          Text(
                            apiResponse
                                ? "Correct sentence"
                                : "Incorrect sentence",
                            style: TextStyle(
                              color: apiResponse ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  "Your sentence was: " + _auxCurrentWords,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Text(
                  apiResponse ? responseText : responseText,
                  style: TextStyle(
                    color: apiResponse ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                Divider(
                  color: Colors.grey,
                  thickness: 1,
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ),
            ],
          );
        },
      );

      await startListening();
    }
  }

  void _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    debugPrint(selectedVal);
  }

  void _logEvent(String eventDescription) {
    if (_logEvents) {
      var eventTime = DateTime.now().toIso8601String();
      debugPrint('$eventTime $eventDescription');
    }
  }

  void _switchLogging(bool? val) {
    setState(() {
      _logEvents = val ?? false;
    });
  }

  void _switchOnDevice(bool? val) {
    setState(() {
      _onDevice = val ?? false;
    });
  }
}

/// Displays the most recently recognized words and the sound level.
class RecognitionResultsWidget extends StatelessWidget {
  const RecognitionResultsWidget({
    super.key,
    required this.lastWords,
    required this.level,
    required this.currentWords,
    required this.speechAvailable,
  });

  final String lastWords;
  final String currentWords;
  final double level;
  final bool speechAvailable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              const Center(
                child: Text(
                  'Recognized Words',
                  style: TextStyle(fontSize: 22.0),
                ),
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Container(
                      color: Theme.of(context).secondaryHeaderColor,
                      child: Center(
                        child: Text(
                          lastWords.isNotEmpty
                              ? '$lastWords $currentWords'
                              : speechAvailable
                                  ? 'Tap the microphone to start listening...'
                                  : 'Speech not available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 600 ? 16.0 : 22.0,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: 10,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: constraints.maxWidth < 600 ? 30 : 40,
                          height: constraints.maxWidth < 600 ? 30 : 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                blurRadius: .26,
                                spreadRadius: level * 1.5,
                                color: Colors.black.withOpacity(.05),
                              ),
                            ],
                            color: Colors.white,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(50)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.mic),
                            iconSize: constraints.maxWidth < 600 ? 20 : 24,
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Speech recognition available',
        style: TextStyle(fontSize: 22.0),
      ),
    );
  }
}

/// Display the current error status from the speech
/// recognizer
class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    super.key,
    required this.lastError,
  });

  final String lastError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Center(
          child: Text(
            'Error Status',
            style: TextStyle(fontSize: 22.0),
          ),
        ),
        Center(
          child: Text(lastError),
        ),
      ],
    );
  }
}

/// Controls to start and stop speech recognition
class SpeechControlWidget extends StatelessWidget {
  const SpeechControlWidget(this.hasSpeech, this.isListening,
      this.startListening, this.stopListening, this.cancelListening,
      {Key? key})
      : super(key: key);

  final bool hasSpeech;
  final bool isListening;
  final void Function() startListening;
  final void Function() stopListening;
  final void Function() cancelListening;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        TextButton(
          onPressed: !hasSpeech || isListening ? null : startListening,
          child: const Text('Start'),
        ),
        TextButton(
          onPressed: isListening ? stopListening : null,
          child: const Text('Stop'),
        ),
        TextButton(
          onPressed: isListening ? cancelListening : null,
          child: const Text('Cancel'),
        )
      ],
    );
  }
}

class SessionOptionsWidget extends StatelessWidget {
  const SessionOptionsWidget(
      this.currentLocaleId,
      this.switchLang,
      this.localeNames,
      this.logEvents,
      this.switchLogging,
      this.pauseForController,
      this.listenForController,
      this.onDevice,
      this.switchOnDevice,
      {Key? key})
      : super(key: key);

  final String currentLocaleId;
  final void Function(String?) switchLang;
  final void Function(bool?) switchLogging;
  final void Function(bool?) switchOnDevice;
  final TextEditingController pauseForController;
  final TextEditingController listenForController;
  final List<LocaleName> localeNames;
  final bool logEvents;
  final bool onDevice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            // Diseño para pantallas pequeñas
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: [
                    const Text('Language: '),
                    DropdownButton<String>(
                      onChanged: (selectedVal) => switchLang(selectedVal),
                      value: currentLocaleId,
                      items: localeNames
                          .map(
                            (localeName) => DropdownMenuItem(
                              value: localeName.localeId,
                              child: Text(localeName.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                //     Column(
                //       children: [
                //         const Text('pauseFor: '),
                //         Container(
                //           padding: const EdgeInsets.only(left: 8),
                //           width: 80,
                //           child: TextFormField(
                //             controller: pauseForController,
                //           ),
                //         ),
                //         Container(
                //             padding: const EdgeInsets.only(left: 16),
                //             child: const Text('listenFor: ')),
                //         Container(
                //           padding: const EdgeInsets.only(left: 8),
                //           width: 80,
                //           child: TextFormField(
                //             controller: listenForController,
                //           ),
                //         ),
                //       ],
                //     ),
                //     Column(
                //       children: [
                //         const Text('On device: '),
                //         Checkbox(
                //           value: onDevice,
                //           onChanged: switchOnDevice,
                //         ),
                //         const Text('Log events: '),
                //         Checkbox(
                //           value: logEvents,
                //           onChanged: switchLogging,
                //         ),
                //       ],
                //     ),
              ],
            );
          } else {
            // Diseño para pantallas grandes
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: [
                    const Text('Language: '),
                    DropdownButton<String>(
                      onChanged: (selectedVal) => switchLang(selectedVal),
                      value: currentLocaleId,
                      items: localeNames
                          .map(
                            (localeName) => DropdownMenuItem(
                              value: localeName.localeId,
                              child: Text(localeName.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                // Row(
                //   children: [
                //     const Text('pauseFor: '),
                //     Container(
                //       padding: const EdgeInsets.only(left: 8),
                //       width: 80,
                //       child: TextFormField(
                //         controller: pauseForController,
                //       ),
                //     ),
                //     Container(
                //         padding: const EdgeInsets.only(left: 16),
                //         child: const Text('listenFor: ')),
                //     Container(
                //       padding: const EdgeInsets.only(left: 8),
                //       width: 80,
                //       child: TextFormField(
                //         controller: listenForController,
                //       ),
                //     ),
                //   ],
                // ),
                // Row(
                //   children: [
                //     const Text('On device: '),
                //     Checkbox(
                //       value: onDevice,
                //       onChanged: switchOnDevice,
                //     ),
                //     const Text('Log events: '),
                //     Checkbox(
                //       value: logEvents,
                //       onChanged: switchLogging,
                //     ),
                //   ],
                // ),
              ],
            );
          }
        },
      ),
    );
  }
}

class InitSpeechWidget extends StatelessWidget {
  const InitSpeechWidget(this.hasSpeech, this.initSpeechState, {Key? key})
      : super(key: key);

  final bool hasSpeech;
  final Future<void> Function() initSpeechState;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        TextButton(
          onPressed: hasSpeech ? null : initSpeechState,
          child: const Text('Initialize'),
        ),
      ],
    );
  }
}

/// Display the current status of the listener
class SpeechStatusWidget extends StatelessWidget {
  const SpeechStatusWidget({
    Key? key,
    required this.speech,
  }) : super(key: key);

  final SpeechToText speech;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Theme.of(context).colorScheme.background,
      child: Center(
        child: speech.isListening
            ? const Text(
                "I'm listening...",
                style: TextStyle(fontWeight: FontWeight.bold),
              )
            : const Text(
                'Not listening',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
