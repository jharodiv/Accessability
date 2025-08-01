import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/huggingface/inference.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
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

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
              _onSearchChanged(result.recognizedWords);
              _handleVoiceCommand(result.recognizedWords);
            });

            // Speech ended
            if (result.finalResult) {
              setState(() {
                _isListening = false;
              });

              // Wait a bit then clear the field
              Future.delayed(const Duration(seconds: 1), () {
                _clearSearch();
              });
            }
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('speechNotAvailable'.tr())),
        );
      }
    }
  }

  void _handleVoiceCommand(String command) async {
    try {
      final result = await predictCommand(command);
      final label = result['label'];
      final confidence = result['confidence'];

      if (confidence >= 50) {
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
            print('Unrecognized label: $label');
        }
      } else {
        print('Low confidence ($confidence%). Command not executed.');
      }
    } catch (e) {
      print("Error $e");
    }

    _searchController.clear();
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _speech.stop();
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
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening
                      ? Colors.red
                      : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                ),
                onPressed: () {
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
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
