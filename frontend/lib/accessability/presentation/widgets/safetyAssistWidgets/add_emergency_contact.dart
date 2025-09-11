import 'package:accessability/accessability/presentation/widgets/dialog/permission_required_dialog_widget.dart';
import 'package:accessability/accessability/presentation/widgets/dialog/try_again_dialog_widget.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:accessability/accessability/utils/contact_service.dart';

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
  bool _loadingContacts = false;

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

  Future<void> _onPickContactPressed() async {
    // Function to handle the actual contact picking after permission is granted
    Future<void> _pickContacts() async {
      setState(() => _loadingContacts = true);

      try {
        final contacts = await ContactService.getContacts();

        if (contacts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('no_contacts_found'.tr())),
          );
          return;
        }

        final Map<String, String>? selectedContact =
            await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => SimpleContactDialog(contacts: contacts),
        );

        if (selectedContact != null) {
          _nameCtrl.text = selectedContact['name'] ?? '';
          _phoneCtrl.text = selectedContact['phone'] ?? '';
          _updateButtonState();
        }
      } catch (e) {
        debugPrint('Error getting contacts: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_reading_contacts'.tr())),
        );
      } finally {
        setState(() => _loadingContacts = false);
      }
    }

    // Check current status first
    var status = await Permission.contacts.status;

    // If already granted, proceed directly
    if (status.isGranted) {
      await _pickContacts();
      return;
    }

    // Always request permission
    status = await Permission.contacts.request();

    if (status.isGranted) {
      await _pickContacts();
    } else if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => PermissionRequiredDialog(
          onOpenSettings: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
        // After returning from settings, check if permission was granted
        await Future.delayed(const Duration(milliseconds: 500));
        status = await Permission.contacts.status;
        if (status.isGranted) {
          await _pickContacts();
        }
      }
    } else if (status.isDenied) {
      // Show explanation and offer to try again
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (context) => TryAgainDialog(
          onTryAgain: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );

      if (shouldRetry == true) {
        _onPickContactPressed(); // Recursive call to try again
      }
    } else if (status.isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('contacts_access_restricted'.tr())),
      );
    }
  }

  void _onSavePressed() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final arrival = _arrivalCtrl.text.trim();

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
                'add_emergency_number'.tr(),
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
                        child: _loadingContacts
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
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
                    maxLines: 3,
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
                  Text('Relationship'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _arrivalCtrl,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'enter_relationship_info'.tr(),
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
                backgroundColor: const Color(0xFF6750A4),
                disabledBackgroundColor: const Color(0xFFDFDFDF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'save'.tr().toUpperCase(),
                      style: TextStyle(
                        color: (_isButtonEnabled && !_saving)
                            ? const Color.fromARGB(255, 255, 255, 255)
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

class SimpleContactDialog extends StatelessWidget {
  final List<Map<String, String>> contacts;

  const SimpleContactDialog({Key? key, required this.contacts})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return Dialog(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'select_contact'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'no_contacts_found'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final phoneNumber = contact['phone'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6750A4),
                            child: Text(
                              contact['name']?.isNotEmpty == true
                                  ? contact['name']![0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            contact['name'] ?? '',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            phoneNumber ?? 'no_phone_number'.tr(),
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(contact),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('cancel'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
