import 'package:AccessAbility/accessability/presentation/widgets/shimmer/shimmer_delete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class DeleteAccount extends StatefulWidget {
  const DeleteAccount({super.key});

  @override
  State<DeleteAccount> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccount> {
  bool _isConfirmed = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          setState(() {
            _isDeleting = true;
          });
        } else {
          setState(() {
            _isDeleting = false;
          });
        }
        if (state is AuthSuccess &&
            state.message == "Account deleted successfully.") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('accountDeletedSuccess'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          // Show shimmer placeholder for a short delay before navigation
          setState(() {
            _isDeleting = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          });
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'error'.tr()}: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
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
                'deleteAccountTitle'.tr(),
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
        body: _isDeleting
            ? const ShimmerDeleteScreen()
            : Container(
                height: double.infinity,
                color: isDarkMode ? Colors.black : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'deleteAccountConfirmation'.tr(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'deleteAccountWarning'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'deleteAccountPrompt'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: '🟣 ',
                                        style:
                                            TextStyle(color: Color(0xFF6750A4)),
                                      ),
                                      TextSpan(
                                        text:
                                            '${'deleteAccountBullet1'.tr()}\n\n',
                                      ),
                                      const TextSpan(
                                        text: '🟣 ',
                                        style:
                                            TextStyle(color: Color(0xFF6750A4)),
                                      ),
                                      TextSpan(
                                        text:
                                            '${'deleteAccountBullet2'.tr()}\n\n',
                                      ),
                                      const TextSpan(
                                        text: '🟣 ',
                                        style:
                                            TextStyle(color: Color(0xFF6750A4)),
                                      ),
                                      TextSpan(
                                        text: 'deleteAccountBullet3'.tr(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Checkbox(
                                      activeColor: const Color(0xFF6750A4),
                                      value: _isConfirmed,
                                      onChanged: (value) {
                                        setState(() {
                                          _isConfirmed = value!;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'deleteAccountConfirmLabel'.tr(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF333333),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: ElevatedButton(
                                    onPressed: _isConfirmed
                                        ? () {
                                            context
                                                .read<AuthBloc>()
                                                .add(DeleteAccountEvent());
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 50, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'deleteAccountButton'.tr(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
