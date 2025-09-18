import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder for EmergencyContactsList
class EmergencyContactsListShimmer extends StatelessWidget {
  final bool isDarkMode;
  final int itemCount;

  const EmergencyContactsListShimmer({
    Key? key,
    required this.isDarkMode,
    this.itemCount = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100;
    final purple = const Color(0xFF6750A4);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // avatar placeholder
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDarkMode
                            ? Colors.grey.shade700
                            : const Color(0xFFEFE7FF),
                        child: Container(), // empty for shimmer
                      ),
                    ),

                    const SizedBox(width: 12),

                    // text block: name + relation + phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // top row: name (shimmer bar) and relation pill (shimmer pill)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // relation pill placeholder
                              Container(
                                width: 56,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // phone row placeholder
                          Row(
                            children: [
                              // small icon circle
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.grey.shade800
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // three-dot button placeholder
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),

              // inset divider
              Padding(
                padding: const EdgeInsets.only(left: 62, right: 6),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
