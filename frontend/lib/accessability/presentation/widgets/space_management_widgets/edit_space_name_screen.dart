import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class EditSpaceNameScreen extends StatefulWidget {
  final String initialName;

  const EditSpaceNameScreen({Key? key, this.initialName = ''})
      : super(key: key);

  @override
  State<EditSpaceNameScreen> createState() => _EditSpaceNameScreenState();
}

class _EditSpaceNameScreenState extends State<EditSpaceNameScreen> {
  late final TextEditingController _controller;
  late String _currentText;
  static const Color _purple = Color(0xFF6750A4);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _currentText = widget.initialName;
    _controller
        .addListener(() => setState(() => _currentText = _controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final trimmed = _currentText.trim();
    return trimmed.isNotEmpty && trimmed != widget.initialName;
  }

  void _saveAndPop() {
    final newName = _currentText.trim();
    if (newName.isEmpty) return;
    Navigator.of(context).pop(newName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Theme(
      data: theme.copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _purple,
          selectionColor:
              isDarkMode ? _purple.withOpacity(0.4) : _purple.withOpacity(0.2),
          selectionHandleColor: _purple,
        ),
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                color: _purple, // stays purple in dark mode
              ),
              title: Text(
                'Edit Space Name'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: _canSave ? _saveAndPop : null,
                  child: Text(
                    'Save'.tr(),
                    style: TextStyle(
                      color: _canSave
                          ? _purple
                          : _purple.withOpacity(0.35), // faded when disabled
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              height: screenHeight * 0.15,
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
              alignment: Alignment.topLeft,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_canSave) _saveAndPop();
                },
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter space name'.tr(),
                  hintStyle: TextStyle(
                    color:
                        isDarkMode ? Colors.white70 : _purple.withOpacity(0.5),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isDarkMode
                          ? Colors.white24
                          : _purple.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: _purple, width: 1.6),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: isDarkMode
                    ? theme.scaffoldBackgroundColor
                    : Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
