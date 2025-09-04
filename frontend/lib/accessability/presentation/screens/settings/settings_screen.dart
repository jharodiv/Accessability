import 'package:accessability/accessability/firebaseServices/auth/auth_service.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:accessability/accessability/logic/bloc/auth/auth_event.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';
import 'package:accessability/accessability/presentation/widgets/dialog/logout_confirmation_dialog_widget.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
    final authBloc = context.read<AuthBloc>();

    try {
      // Clear the active space ID from SharedPreferences before logging out
      await _clearActiveSpaceId();

      await authService.signOut();
      authBloc.add(LogoutEvent());
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', // the route you want as new root
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('error'.tr()),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
      print('Cleared active space ID from SharedPreferences');
    } catch (e) {
      print('Error clearing active space ID: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger rebuild when the locale changes.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        // Get biometric login status from the user model.
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
                ListTile(
                  leading: const Icon(Icons.person_2_outlined,
                      color: Color(0xFF6750A4)),
                  title: Text(
                    'account'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/account');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.tune, color: Color(0xFF6750A4)),
                  title: Text(
                    'preference'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/preferences');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.space_dashboard_outlined,
                      color: Color(0xFF6750A4)),
                  title: Text(
                    'spaceManagement'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    // wait for SpaceManagementScreen to finish
                    final result =
                        await Navigator.pushNamed(context, '/spaceManagement');

                    // if it returned an update, forward it up the stack to the widget that opened Settings
                    if (result is Map && result['spaceUpdated'] == true) {
                      // bubble the exact result up by popping Settings with the same result
                      Navigator.of(context).pop(result);

                      // optionally: show feedback and keep Settings open instead of popping:
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   SnackBar(content: Text('Space updated')),
                      // );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined,
                      color: Color(0xFF6750A4)),
                  title: Text(
                    'notification'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Switch(
                    activeColor: const Color(0xFF6750A4),
                    value: isNotificationEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        isNotificationEnabled = value;
                      });
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security_outlined,
                      color: Color(0xFF6750A4)),
                  title: Text(
                    'privacySecurity'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/privacy');
                  },
                ),
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.fingerprint, color: Color(0xFF6750A4)),
                  title: Text(
                    'biometricLogin'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: biometricEnabled
                      ? Text(
                          biometricEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: biometricEnabled
                                ? const Color(0xFF6750A4)
                                : const Color(0xFF5A5757),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pushNamed(context, '/biometric');
                  },
                ),
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: Color(0xFF6750A4)),
                  title: Text(
                    'about'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/about');
                  },
                ),
                // const Divider(),
                // ListTile(
                //   leading: const Icon(Icons.map, color: Color(0xFF6750A4)),
                //   title: const Text('Map View', style: TextStyle(fontWeight: FontWeight.bold)),
                //   onTap: () async {
                //     // Open MapViewScreen. You can pass an initial perspective if needed.
                //     final perspective = await Navigator.push(
                //       context,
                //       MaterialPageRoute(builder: (_) => const MapViewScreen()),
                //     );
                //     if (perspective != null && perspective is MapPerspective) {
                //       // Pass the selected perspective into the homescreen/GpsScreen.
                //       Navigator.pushNamedAndRemoveUntil(
                //         context,
                //         '/homescreen',
                //         (route) => false,
                //         arguments: perspective,
                //       );
                //     }
                //   },
                // ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF6750A4)),
                  title: Text(
                    'logout'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
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
}
