import 'package:flutter/material.dart';
//import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/huggingface/inference.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/Dory/VoiceCommandService.dart';

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
  //final stt.SpeechToText _speech = stt.SpeechToText();
  //bool _isListening = false;
  List<String> _suggestions = [];

  late VoiceCommandService _voiceService;
  VoiceCommandState _voiceState = VoiceCommandState.idle();
  bool _isVoiceServiceInitialized = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeVoiceService();
  }

  void _initializeVoiceService() async {
    _voiceService = VoiceCommandService();

    bool granted = await _voiceService.requestMicrophonePermission();
    if (!granted) {
      print("Microphone permission denied");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Microphone Permission Denied")),
      );
      return;
    }

    _voiceService.stateStream.listen((state) {
      print('[VoiceState] status: ${state.status}, label: ${state.label}');
      setState(() {
        _voiceState = state;
      });
      _handleVoiceCommandState(state);
    });

    final success = await _voiceService.initialize();
    print('Voice service initialized: $success');
    setState(() {
      _isVoiceServiceInitialized = success;
    });

    if (success) {
      await _voiceService.startListening();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('voiceServiceNotAvailable'.tr())),
      );
    }
  }

  void _handleVoiceCommandState(VoiceCommandState state) {
    switch (state.status) {
      case VoiceCommandStatus.executeNavigation:
        if (state.label != null) {
          _executeNavigationCommand(state.label!);
        }
        break;

      case VoiceCommandStatus.processingCommand:
        // Show the command being processed in search bar (optional)
        if (state.command != null) {
          setState(() {
            _searchController.text = state.command!;
          });
        }
        break;

      case VoiceCommandStatus.commandExecuted:
        // Clear search bar after command execution
        Future.delayed(const Duration(seconds: 1), () {
          _clearSearch();
        });
        break;

      case VoiceCommandStatus.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message ?? 'Voice command error'),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case VoiceCommandStatus.lowConfidence:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not understand command. Please try again.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;

      default:
        break;
    }
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

  void _executeNavigationCommand(String label) {
    // Your existing navigation logic (keep the switch statement the same)
    switch (label.toLowerCase()) {
      case 'open_settings':
        Navigator.pushNamed(context, '/settings');
        break;
      // ... keep all your existing cases exactly the same
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unrecognized command: $label'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  void _toggleVoiceListening() async {
    if (!_isVoiceServiceInitialized) return;

    if (_isVoiceListening()) {
      await _voiceService.stopListening();
    } else {
      await _voiceService.startListening();
    }
  }

  bool _isVoiceListening() {
    return [
      VoiceCommandStatus.ready,
      VoiceCommandStatus.listeningForDory,
      VoiceCommandStatus.doryDetected,
      VoiceCommandStatus.listeningForCommand,
    ].contains(_voiceState.status);
  }

  Color _getVoiceMicColor(bool isDarkMode) {
    switch (_voiceState.status) {
      case VoiceCommandStatus.listeningForDory:
        return Colors.orange;
      case VoiceCommandStatus.doryDetected:
        return Colors.green;
      case VoiceCommandStatus.listeningForCommand:
        return Colors.purple;
      case VoiceCommandStatus.processingCommand:
        return Colors.blue;
      case VoiceCommandStatus.error:
        return Colors.red;
      default:
        return isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;
    }
  }

  IconData _getVoiceMicIcon() {
    switch (_voiceState.status) {
      case VoiceCommandStatus.listeningForDory:
        return Icons.hearing;
      case VoiceCommandStatus.doryDetected:
        return Icons.pets;
      case VoiceCommandStatus.listeningForCommand:
        return Icons.record_voice_over;
      case VoiceCommandStatus.processingCommand:
        return Icons.psychology;
      case VoiceCommandStatus.commandExecuted:
        return Icons.check;
      case VoiceCommandStatus.error:
        return Icons.error;
      default:
        return _isVoiceListening() ? Icons.mic : Icons.mic_none;
    }
  }

  String _getVoiceTooltip() {
    switch (_voiceState.status) {
      case VoiceCommandStatus.idle:
        return 'Start voice commands';
      case VoiceCommandStatus.listeningForDory:
        return 'Say "Dory" to activate';
      case VoiceCommandStatus.doryDetected:
        return 'Dory heard! Say your command';
      case VoiceCommandStatus.listeningForCommand:
        return 'Listening for command...';
      case VoiceCommandStatus.processingCommand:
        return 'Processing command...';
      case VoiceCommandStatus.error:
        return 'Voice command error';
      default:
        return 'Voice commands';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _voiceService.dispose();
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
          height: 50, // Fixed height for the search bar
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
                    hintText: 'searchLocationHint'.tr(),
                    hintStyle: TextStyle(
                        color:
                            isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(color: textColor),
                  onChanged: _onSearchChanged,
                  onSubmitted: widget.onSearch,
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                  onPressed: _clearSearch,
                ),
              Tooltip(
                message: _getVoiceTooltip(),
                child: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _getVoiceMicIcon(),
                      key: ValueKey(_voiceState.status),
                      color: _getVoiceMicColor(isDarkMode),
                    ),
                  ),
                  onPressed:
                      _isVoiceServiceInitialized ? _toggleVoiceListening : null,
                ),
              ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            constraints: const BoxConstraints(
              maxHeight: 200, // Constrain the height of the suggestions list
            ),
            decoration: BoxDecoration(
              color: backgroundColor, // Use theme-based background color
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
                    style: TextStyle(
                        color: textColor), // Use theme-based text color
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
