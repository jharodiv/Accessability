import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

class JoinSpaceWidget extends StatelessWidget {
  final List<TextEditingController> verificationCodeControllers;
  final List<FocusNode> verificationCodeFocusNodes;
  final VoidCallback onJoinSpace;
  final VoidCallback onCancel;
  final VoidCallback onCodeInput;

  const JoinSpaceWidget({
    Key? key,
    required this.verificationCodeControllers,
    required this.verificationCodeFocusNodes,
    required this.onJoinSpace,
    required this.onCancel,
    required this.onCodeInput,
  }) : super(key: key);

  Widget _buildBox(int i, double width) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: width,
      child: Focus(
        // Focus creates its own node so we don’t clash with the TextField’s node
        onKey: (node, evt) {
          if (evt is RawKeyDownEvent &&
              evt.logicalKey == LogicalKeyboardKey.backspace &&
              verificationCodeControllers[i].text.isEmpty) {
            // if empty and not the first box, move back
            if (i > 0) {
              verificationCodeControllers[i - 1].clear();
              verificationCodeFocusNodes[i - 1].requestFocus();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: verificationCodeControllers[i],
          focusNode: verificationCodeFocusNodes[i],
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
            if (val.isNotEmpty) {
              onCodeInput();
              // move forward or unfocus on last box
              if (i < verificationCodeFocusNodes.length - 1) {
                verificationCodeFocusNodes[i + 1].requestFocus();
              } else {
                verificationCodeFocusNodes[i].unfocus();
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Text(
            'enter_invite_code'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Subheading
          Text(
            'invite_code_subheading'.tr(),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Code Input Fields
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth * 0.12;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // First 3 fields
                  for (int i = 0; i < 3; i++) _buildBox(i, fieldWidth),
                  const SizedBox(width: 8),
                  const Text('-', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  // Last 3 fields
                  for (int i = 3; i < 6; i++) _buildBox(i, fieldWidth),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onJoinSpace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: shape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'submit'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6750A4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: shape,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'back'.tr(),
                      style: const TextStyle(color: Color(0xFF6750A4)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
