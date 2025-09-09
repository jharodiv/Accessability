import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:easy_localization/easy_localization.dart';
import 'huggingface/dory_service.dart';
import 'melody/melody_manager.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SearchBarWithAutocomplete extends StatefulWidget {
  final Function(String) onSearch;

  const SearchBarWithAutocomplete({super.key, required this.onSearch});

  @override
  _SearchBarWithAutocompleteState createState() =>
      _SearchBarWithAutocompleteState();
}

class _SearchBarWithAutocompleteState extends State<SearchBarWithAutocomplete> {
  final TextEditingController _searchController = TextEditingController();
  final OpenStreetMapGeocodingService _geocodingService =
      OpenStreetMapGeocodingService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  List<String> _suggestions = [];
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;

  //For Porcupine Integration
  late MelodyManager _melodyManager;
  bool _isWakeWordListening = false;
  bool _isProcessingWakeWord = false;

  //Tts Integration
  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();

    _melodyManager = MelodyManager(onWakeWordDetected: onWakeWordDetected);

    //Tts Integration
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.9);

    _flutterTts.setCompletionHandler(() {
      print("✅ Melody finished speaking");
      _startDoryListening();
    });
  }

  void _initializeSpeech() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('speechNotAvailable'.tr())),
      );
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  void onWakeWordDetected() async {
    print("✅☑️ Wake Word Detected");

    if (_isProcessingWakeWord || _isListening) return;

    setState(() {
      _isProcessingWakeWord = true;
    });

    _melodyManager.stop();

    await _speech.stop();

    await _speak("Hi, what can I do for you?");
  }

  void _onSearchChanged(String query) async {
    if (query.isNotEmpty) {
      try {
        final suggestions =
            await _geocodingService.getAutocompleteSuggestions(query);
        setState(() {
          _suggestions = suggestions;
        });
      } catch (e) {
        setState(() {
          _suggestions = [];
        });
      }
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _onSuggestionSelected(String suggestion) {
    _searchController.text = suggestion;
    setState(() {
      _suggestions = [];
    });
    widget.onSearch(suggestion);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _suggestions = [];
    });
  }

  // Renamed and modified for wake word triggered listening
  void _startDoryListening() async {
    print("🎤 Starting Dory listening after wake word...");

    if (_isListening) {
      print("⚠️ Already listening, stopping previous session");
      _speech.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    //bool available = await _speech.initialize();
    if (!_speech.isAvailable) {
      print("❌ Speech not available");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('speechNotAvailable'.tr())),
      );
      setState(() {
        _isProcessingWakeWord = false;
      });
      return;
    }

    setState(() {
      _isListening = true;
      _searchController.text = "Listening..."; // Visual feedback
    });

    print("🎯 Speech listening started for Dory commands");

    _speech.listen(
      onResult: (result) async {
        print(
            "🗣️ Speech result: ${result.recognizedWords} (final: ${result.finalResult})");

        setState(() {
          _searchController.text = result.recognizedWords;
        });

        // Process command only when we have final result
        if (result.finalResult) {
          final command = result.recognizedWords.trim();
          print("🚀 Final command for Dory: '$command'");

          // Send to Dory for processing
          await _handleVoiceCommand(command);

          // Clean up
          setState(() {
            _isListening = false;
            _isProcessingWakeWord = false;
          });

          // Clear search after processing
          Future.delayed(const Duration(seconds: 1), () {
            _clearSearch();
          });
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      onSoundLevelChange: (level) {},
      cancelOnError: true,
      localeId: 'en_US',
    );
  }

  // Regular listening (triggered by manual mic button)
  void _startListening() async {
    if (_isListening) return;

    bool available = await _speech.initialize();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('speechNotAvailable'.tr())),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    _speech.listen(
      onResult: (result) async {
        setState(() {
          _searchController.text = result.recognizedWords;
          _onSearchChanged(result.recognizedWords);
        });

        if (result.finalResult) {
          final command = result.recognizedWords.trim();
          print("Manual command: $command");

          await _handleVoiceCommand(command);

          setState(() {
            _isListening = false;
          });

          Future.delayed(const Duration(seconds: 1), () {
            _clearSearch();
          });
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 1),
      partialResults: false,
      cancelOnError: true,
    );
  }

  _handleVoiceCommand(String command) async {
    print("🧠 Processing command with Dory: '$command'");

    try {
      final result = await predictCommand(command);
      final label = result['label'];
      final confidence = result['confidence'];

      print("🎯 Dory result - Label: $label, Confidence: $confidence%");

      if (confidence >= 50) {
        print("✅ Executing command: $label");

        switch (label) {
          case 'open_settings':
            Navigator.pushNamed(context, '/settings');
            break;

          case 'call_sos':
            Navigator.pushNamed(context, '/sos');
            break;

          case 'open_chat':
            Navigator.pushNamed(context, '/inbox');
            break;

          case 'opencreate_space':
            Navigator.pushNamed(context, '/createSpace');
            break;

          case 'find_location':
            Navigator.pushNamed(context, '/map');
            break;

          case 'pwd_route':
            Navigator.pushNamed(context, '/pwdRoute');
            break;

          case 'open_account':
            Navigator.pushNamed(context, '/account');
            break;

          case 'set_checkin':
            Navigator.pushNamed(context, '/checkin');
            break;

          case 'open_safety_contact':
            Navigator.pushNamed(context, '/safetyContact');
            break;

          case 'open_favorites':
            Navigator.pushNamed(context, '/favorites');
            break;

          default:
            print('❓ Unrecognized label: $label');
            // Optional: Show user feedback for unrecognized commands
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Command not recognized: $command')),
            );
        }
      } else {
        print('⚠️ Low confidence ($confidence%). Command not executed.');
        // Optional: Show user feedback for low confidence
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Command unclear, please try again')),
        );
      }
    } catch (e) {
      print("❌ Error processing command: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing voice command')),
      );
    }

    _searchController.clear();
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _isProcessingWakeWord = false;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _speech.stop();
    _melodyManager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _isProcessingWakeWord
                        ? 'Say your command...'
                        : 'searchLocationHint'.tr(),
                    hintStyle: TextStyle(
                        color: _isProcessingWakeWord
                            ? Colors.green
                            : (isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[700])),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                      color: _isProcessingWakeWord ? Colors.green : textColor),
                  onChanged: _onSearchChanged,
                  onSubmitted: widget.onSearch,
                ),
              ),
              if (_searchController.text.isNotEmpty && !_isListening)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  onPressed: _clearSearch,
                ),
              IconButton(
                icon: Icon(
                  _isListening
                      ? Icons.mic
                      : (_isWakeWordListening
                          ? Icons.mic_external_on
                          : Icons.mic_none),
                  color: _isListening
                      ? Colors.green
                      : (_isWakeWordListening
                          ? Colors.red
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[700])),
                ),
                onPressed: () {
                  if (_isListening) {
                    // Stop current listening
                    _stopListening();
                  } else if (_isWakeWordListening) {
                    // Stop wake word listening
                    _melodyManager.stop();
                    setState(() {
                      _isWakeWordListening = false;
                    });
                  } else {
                    // Start wake word listening
                    _melodyManager.start();
                    setState(() {
                      _isWakeWordListening = true;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            constraints: const BoxConstraints(
              maxHeight: 200,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _suggestions[index],
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () => _onSuggestionSelected(_suggestions[index]),
                );
              },
            ),
          ),
      ],
    );
  }
}
