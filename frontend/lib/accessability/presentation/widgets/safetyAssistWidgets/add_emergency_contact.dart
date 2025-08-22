// lib/presentation/widgets/bottomSheetWidgets/add_emergency_contact_screen.dart

import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class AddEmergencyContactScreen extends StatefulWidget {
  final String uid;
  const AddEmergencyContactScreen({Key? key, required this.uid})
      : super(key: key);

  @override
  _AddEmergencyContactScreenState createState() =>
      _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState extends State<AddEmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _arrivalCtrl = TextEditingController();

  bool _saving = false;
  bool _isButtonEnabled = false;

  void _updateButtonState() {
    final enabled =
        _nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty;
    if (enabled != _isButtonEnabled) {
      setState(() => _isButtonEnabled = enabled);
    }
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_updateButtonState);
    _phoneCtrl.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_updateButtonState);
    _phoneCtrl.removeListener(_updateButtonState);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _arrivalCtrl.dispose();
    super.dispose();
  }

  void _onPickContactPressed() {
    // Placeholder for picking from device contacts.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('contact_picker_not_implemented'.tr())),
    );
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final arrival = _arrivalCtrl.text.trim();

    // Return values to caller; parent will dispatch the bloc event
    Navigator.of(context).pop({
      'name': name,
      'phone': phone,
      'location': address,
      'arrival': arrival,
    });

    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: SafeArea(
          top: true,
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
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF6750A4),
              ),
              title: Text(
                'add_emergency_number'
                    .tr(), // or 'settings'.tr() depending on screen
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('contact_name'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'enter_contact_name'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'required'.tr();
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  Text('phone_number'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'enter_phone_number'.tr(),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'required'.tr();
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.contact_phone),
                          onPressed: _onPickContactPressed,
                          tooltip: 'pick_from_contacts'.tr(),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text('address'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'enter_contact_address'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Optional arrival/info field
                  Text('arrival'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _arrivalCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'enter_arrival_info'.tr(),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isButtonEnabled && !_saving) ? _onSavePressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0),
                disabledBackgroundColor: const Color(0xFFDFDFDF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                'save'.tr().toUpperCase(),
                style: TextStyle(
                  color: (_isButtonEnabled && !_saving)
                      ? Colors.black
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
    );
  }
}
