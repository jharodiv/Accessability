import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

const Color _purple = Color(0xFF6750A4);

class RemoveConfirmDialogWidget extends StatefulWidget {
  final int count;
  const RemoveConfirmDialogWidget({Key? key, required this.count})
      : super(key: key);

  @override
  State<RemoveConfirmDialogWidget> createState() =>
      _RemoveConfirmDialogWidgetState();
}

class _RemoveConfirmDialogWidgetState extends State<RemoveConfirmDialogWidget> {
  bool _isProcessing = false;

  Future<void> _onRemovePressed() async {
    setState(() => _isProcessing = true);

    // small artificial delay can be removed; we just want to show spinner briefly if needed
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[850] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: bg,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'removeMember'
                      .tr(), // you can add this key, or replace with plain text
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // show message: removing N selected members
                  'Are you sure you want to remove ${widget.count} member${widget.count == 1 ? '' : 's'}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!),
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.white,
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(
                          'cancel'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isProcessing ? null : _onRemovePressed,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Remove'.tr(), // or plain 'Remove'
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // decorative top circle (trash icon)
          Positioned(
            top: -40,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              child: Image.asset(
                'assets/images/authentication/authenticationImage.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
