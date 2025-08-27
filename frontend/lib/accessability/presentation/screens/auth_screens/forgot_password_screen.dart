import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/presentation/widgets/accessability_header.dart';
import 'package:AccessAbility/accessability/presentation/widgets/auth_widgets/forgot_password_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();

  /// This callback runs on *any* pop (system back or appBar back)
  Future<bool> _onWillPop() {
    context.read<AuthBloc>().add(ResetAuthState());
    return Future.value(true); // allow the pop
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // register our callback
    ModalRoute.of(context)!.addScopedWillPopCallback(_onWillPop);
  }

  @override
  void dispose() {
    // unregister it to avoid memory leaks
    ModalRoute.of(context)!.removeScopedWillPopCallback(_onWillPop);
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // this Navigator.pop will also trigger _onWillPop
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isOverflowing = constraints.maxHeight < 600;
            return SingleChildScrollView(
              physics: isOverflowing
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  const Accessabilityheader(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Forgotpasswordconfirmation(
                      emailController: emailController,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
