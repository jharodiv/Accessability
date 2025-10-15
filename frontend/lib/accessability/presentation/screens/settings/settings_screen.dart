import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';
import 'package:accessability/accessability/presentation/widgets/dialog/logout_confirmation_dialog_widget.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:accessability/accessability/services/tts_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
    final authBloc = context.read<AuthBloc>();

    try {
      await _clearActiveSpaceId();
      await authService.signOut();

      authBloc.add(LogoutEvent());
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      TtsService.instance.speak('You have been logged out successfully.');
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('error'.tr()),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearActiveSpaceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_active_space_id');
      debugPrint('✅ Cleared active space ID from SharedPreferences');
    } catch (e) {
      debugPrint('⚠️ Error clearing active space ID: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        bool biometricEnabled = false;
        if (state is UserLoaded) {
          biometricEnabled = state.user.biometricEnabled;
        }

        return Scaffold(
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
                leading: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    TtsService.instance.speak('Back to previous screen');
                  },
                  icon: const Icon(Icons.arrow_back),
                  color: const Color(0xFF6750A4),
                ),
                title: Text(
                  'settings'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
          body: Container(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            child: ListView(
              children: [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_2_outlined,
                  label: 'account'.tr(),
                  route: '/account',
                ),
                const Divider(),
                _buildSettingsTile(
                  context,
                  icon: Icons.tune,
                  label: 'preference'.tr(),
                  route: '/preferences',
                ),
                const Divider(),
                _buildSettingsTile(
                  context,
                  icon: Icons.space_dashboard_outlined,
                  label: 'spaceManagement'.tr(),
                  route: '/spaceManagement',
                  afterReturn: (result) {
                    if (result is Map && result['spaceUpdated'] == true) {
                      Navigator.of(context).pop(result);
                    }
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(
                    'notification'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF6750A4),
                  ),
                  activeColor: const Color(0xFF6750A4),
                  value: isNotificationEnabled,
                  onChanged: (value) {
                    setState(() => isNotificationEnabled = value);
                    TtsService.instance.speak(
                      value
                          ? 'Notifications enabled'
                          : 'Notifications disabled',
                    );
                  },
                ),
                const Divider(),
                _buildSettingsTile(
                  context,
                  icon: Icons.security_outlined,
                  label: 'privacySecurity'.tr(),
                  route: '/privacy',
                ),
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.fingerprint, color: Color(0xFF6750A4)),
                  title: Text(
                    'biometricLogin'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    biometricEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: biometricEnabled
                          ? const Color(0xFF6750A4)
                          : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/biometric');
                    TtsService.instance.speak('Biometric login settings');
                  },
                ),
                const Divider(),
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline,
                  label: 'about'.tr(),
                  route: '/about',
                ),
                const Divider(),
                _buildSettingsTile(
                  context,
                  icon: Icons.help_outline,
                  label: 'FAQ'.tr(),
                  route: '/faq',
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF6750A4)),
                  title: Text(
                    'logout'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    TtsService.instance
                        .speak('Are you sure you want to logout?');
                    showDialog(
                      context: context,
                      builder: (_) => LogoutConfirmationDialogWidget(
                        onConfirm: () => logout(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Helper function to build each tile with optional callback
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    Function(dynamic result)? afterReturn,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6750A4)),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        TtsService.instance.speak(label);
        final result = await Navigator.pushNamed(context, route);
        if (afterReturn != null) afterReturn(result);
      },
    );
  }
}
