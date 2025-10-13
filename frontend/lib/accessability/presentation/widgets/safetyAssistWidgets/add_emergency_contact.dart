// lib/presentation/screens/add_emergency_contact_screen.dart
import 'package:accessability/accessability/presentation/widgets/dialog/permission_required_dialog_widget.dart';
import 'package:accessability/accessability/presentation/widgets/dialog/try_again_dialog_widget.dart';
import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/simple_contact_dialog.dart';
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

class _AddEmergencyContactScreenState extends State<AddEmergencyContactScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _relationCtrl = TextEditingController();

  bool _saving = false;
  bool _isButtonEnabled = false;
  bool _loadingContacts = false;

  // Country code selector
  String _countryCode = '+63';
  final List<String> _countryCodes = ['+63', '+1', '+44', '+61', '+65'];

  late AnimationController _buttonAnim;

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
    _buttonAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_updateButtonState);
    _phoneCtrl.removeListener(_updateButtonState);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _relationCtrl.dispose();
    _buttonAnim.dispose();
    super.dispose();
  }

  Future<void> _onPickContactPressed() async {
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
          // Name
          _nameCtrl.text = selectedContact['name'] ?? '';

          // Phone: try to extract leading +countrycode and leftover number
          final raw = (selectedContact['phone'] ?? '').trim();
          if (raw.isNotEmpty) {
            // remove whitespace (keeps + and digits and other chars intact for later parsing)
            final cleaned = raw.replaceAll(RegExp(r'\s+'), '');

            // Try to match a known country code from _countryCodes (longest first)
            String? matchedCc;
            final codes = List<String>.from(_countryCodes);
            codes.sort((a, b) => b.length.compareTo(a.length)); // longest first
            for (final cc in codes) {
              if (cleaned.startsWith(cc)) {
                matchedCc = cc;
                break;
              }
            }

            if (matchedCc != null) {
              // extract remainder after cc, remove non-digits, strip leading zeros
              var rest = cleaned
                  .substring(matchedCc.length)
                  .replaceAll(RegExp(r'\D'), '');
              rest =
                  rest.replaceFirst(RegExp(r'^0+'), ''); // remove leading zeros
              setState(() => _countryCode = matchedCc!);
              _phoneCtrl.text = rest;
            } else {
              // fallback: detect a +countrycode (1-4 digits) using regex like before
              final m = RegExp(r'^\+[\d]{1,4}').firstMatch(cleaned);
              if (m != null) {
                final cc = m.group(0)!;
                var rest =
                    cleaned.substring(cc.length).replaceAll(RegExp(r'\D'), '');
                rest = rest.replaceFirst(
                    RegExp(r'^0+'), ''); // remove leading zeros
                setState(() {
                  _countryCode = cc;
                  if (!_countryCodes.contains(cc)) _countryCodes.insert(0, cc);
                });
                _phoneCtrl.text = rest;
              } else {
                // No country + prefix, just keep digits and strip leading zeros
                _phoneCtrl.text = cleaned
                    .replaceAll(RegExp(r'\D'), '')
                    .replaceFirst(RegExp(r'^0+'), '');
              }
            }
          } else {
            _phoneCtrl.text = '';
          }
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

    var status = await Permission.contacts.status;
    if (status.isGranted) {
      await _pickContacts();
      return;
    }

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
        await Future.delayed(const Duration(milliseconds: 500));
        status = await Permission.contacts.status;
        if (status.isGranted) {
          await _pickContacts();
        }
      }
    } else if (status.isDenied) {
      final shouldRetry = await showDialog<bool>(
        context: context,
        builder: (context) => TryAgainDialog(
          onTryAgain: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );

      if (shouldRetry == true) {
        _onPickContactPressed();
      }
    } else if (status.isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contacts_access_restricted'.tr())));
    }
  }

  void _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _buttonAnim.forward();
    });

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final relation = _relationCtrl.text.trim();
    final fullPhone = '$_countryCode$phone';

    // stop spinner & animation before popping; guard with mounted
    if (mounted) {
      setState(() {
        _saving = false;
      });

      // reverse returns a TickerFuture; await it so the animation finishes cleanly
      await _buttonAnim.reverse();

      // IMPORTANT: use the key your model/ui expects — here I use "relationship"
      Navigator.of(context).pop({
        'name': name,
        'phone': fullPhone,
        'location': address,
        'relationship': relation,
      });
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    required bool dark,
    bool isMultiLine = false,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Padding(
        padding: EdgeInsets.only(left: 12, right: 8, top: isMultiLine ? 12 : 0),
        child: Icon(icon,
            size: 20, color: dark ? Colors.white70 : Colors.grey[700]),
      ),
      prefixIconConstraints: BoxConstraints(
        minWidth: 40,
        minHeight: isMultiLine ? 48 : 40,
      ),
      filled: true,
      fillColor: dark ? Colors.grey[850] : Colors.grey[100],
      contentPadding: EdgeInsets.symmetric(
        vertical: isMultiLine ? 18 : 16,
        horizontal: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bg = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F8FB);
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDarkMode ? Colors.white70 : Colors.grey[700];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: SafeArea(
          top: true,
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                icon: const Icon(
                  Icons.arrow_back,
                  color:
                      Color(0xFF6750A4), // 🔹 Always purple, even in dark mode
                ),
              ),
              title: Text(
                'add_emergency_number'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDarkMode ? const Color(0xFF1E1E1E) : null,
                gradient: isDarkMode
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFF6F2FF), Color(0xFFFFFFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6750A4), Color(0xFFB388EB)]),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'add_emergency_contact_title'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'add_emergency_contact_subtitle'.tr(),
                          style: TextStyle(fontSize: 13, color: hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Form card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.05 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    hintStyle: TextStyle(color: hintColor),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('contact_name'.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textColor),
                        decoration: _decoration(
                            hint: 'enter_contact_name'.tr(),
                            icon: Icons.person,
                            dark: isDarkMode),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'required'.tr()
                            : null,
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _loadingContacts ? null : _onPickContactPressed,
                          icon: const Icon(Icons.contact_phone,
                              size: 18, color: Colors.white),
                          label: Text('pick_from_contacts'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: isDarkMode
                                ? const Color(0xFF7C5BE6).withOpacity(0.85)
                                : const Color(0xFF7C5BE6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text('phone_number'.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor)),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              value: _countryCode,
                              dropdownColor: cardBg,
                              style: TextStyle(color: textColor),
                              items: _countryCodes
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _countryCode = v ?? _countryCode),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: textColor),
                              decoration: _decoration(
                                hint: 'enter_phone_number'.tr(),
                                icon: Icons.phone,
                                dark: isDarkMode,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'required'.tr()
                                  : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Text('address'.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor)),
                      const SizedBox(height: 8),

                      // Address
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Icon(Icons.location_on,
                                  size: 20, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _addressCtrl,
                                maxLines: 3,
                                textInputAction: TextInputAction.newline,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'enter_contact_address'.tr(),
                                  hintStyle: TextStyle(color: hintColor),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text('relationship'.tr(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _relationCtrl,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(color: textColor),
                        decoration: _decoration(
                          hint: 'enter_relationship_info'.tr(),
                          icon: Icons.group,
                          dark: isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),
            Center(
              child: Text(
                'tip_add_emergency_contact'.tr(),
                style: TextStyle(fontSize: 12, color: hintColor),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isButtonEnabled && !_saving) ? _onSavePressed : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isButtonEnabled
                    ? const Color(0xFF6750A4) // 🔹 active = purple
                    : (isDarkMode
                        ? Colors.grey[800] // 🔹 dark mode disabled = light gray
                        : const Color(0xFFDFDFDF)), // 🔹 light mode disabled
                disabledBackgroundColor:
                    isDarkMode ? Colors.grey[800] : const Color(0xFFDFDFDF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save, size: 18, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          'save'.tr().toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
