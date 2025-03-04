import 'package:AccessAbility/accessability/presentation/widgets/shimmer/shimmer_delete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';

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
            const SnackBar(
              content: Text('Account deleted successfully.'),
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
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
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
              title: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            ),
          ),
        ),
        body: _isDeleting
            ? const ShimmerDeleteScreen()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Deletion Confirmation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'This action will permanently delete your account and remove you from all spaces on Accessability. This process cannot be undone.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Please confirm that you understand the following:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black87),
                                children: [
                                  TextSpan(
                                    text: '🟣 ',
                                    style: TextStyle(color: Color(0xFF6750A4)),
                                  ),
                                  TextSpan(
                                    text:
                                        'Deleting your account is permanent and cannot be undone.\n\n',
                                  ),
                                  TextSpan(
                                    text: '🟣 ',
                                    style: TextStyle(color: Color(0xFF6750A4)),
                                  ),
                                  TextSpan(
                                    text:
                                        'You will be removed from all spaces and your location will no longer be shared.\n\n',
                                  ),
                                  TextSpan(
                                    text: '🟣 ',
                                    style: TextStyle(color: Color(0xFF6750A4)),
                                  ),
                                  TextSpan(
                                    text:
                                        'An email will be sent to confirm your deletion request. (Check your spam folder if not received)',
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
                                const Expanded(
                                  child: Text(
                                    'Yes, I confirm the above',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF333333),
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
                                child: const Text(
                                  'Delete Account',
                                  style: TextStyle(
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
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
