import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

/// Emergency hotline list widget — white background, all-black text/icons,
/// slightly larger sizes for readability.
class SafetyAssistEmergencyServices extends StatelessWidget {
  const SafetyAssistEmergencyServices({Key? key}) : super(key: key);

  static const List<Map<String, String>> _services = [
    {
      'title': 'DAGUPAN PNP',
      'subtitle': 'PHILIPPINE NATIONAL POLICE',
      'numbers': '0916-525-6802 | 529-3633',
      'primary': '09165256802'
    },
    {
      'title': 'BFP DAGUPAN',
      'subtitle': 'BUREAU OF FIRE PROTECTION',
      'numbers': '0917-184-2611 | 522-2772',
      'primary': '09171842611'
    },
    {
      'title': 'PANDA',
      'subtitle': 'PANDA VOLUNTEERS',
      'numbers': '522-2808 | 0932-548-1545',
      'primary': '5222808'
    },
    {
      'title': 'RED CROSS DAGUPAN',
      'subtitle': 'PHILIPPINE NATIONAL RED CROSS',
      'numbers': '632-3292 | 0922-559-2701',
      'primary': '6323292'
    },
    {
      'title': 'CITY HEALTH OFFICE',
      'subtitle': 'DAGUPAN CITY HEALTH OFFICE',
      'numbers': '0933-861-6088 | 0997-840-1377',
      'primary': '09338616088'
    },
    {
      'title': 'POSO DAGUPAN',
      'subtitle': 'PUBLIC ORDER AND SAFETY OFFICE',
      'numbers': '615-6184',
      'primary': '6156184'
    },
    {
      'title': 'CDRRMO',
      'subtitle': 'CITY DISASTER RISK REDUCTION & MANAGEMENT OFFICE',
      'numbers': '0968-444-9598 | 540-0363',
      'primary': '09684449598'
    },
    {
      'title': 'CSWD',
      'subtitle': 'CITY SOCIAL WELFARE AND DEVELOPMENT OFFICE',
      'numbers': '515-3140',
      'primary': '5153140'
    },
    {
      'title': 'OFW DESK',
      'subtitle': 'PESO DAGUPAN - OFW HELP DESK',
      'numbers': '0950-334-1807',
      'primary': '09503341807'
    },
    {
      'title': 'ANTI-VAWC',
      'subtitle': 'VIOLENCE AGAINST WOMEN & CHILDREN HELP DESK',
      'numbers': '0933-378-8888',
      'primary': '09333788888'
    },
  ];

  Future<void> _callNumber(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('cannot_launch_phone'.tr())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _sendSms(BuildContext context, String number) async {
    final uri = Uri(scheme: 'sms', path: number);
    try {
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('cannot_launch_sms'.tr())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // White background, black text/icons, larger sizes for readability
    const bgColor = Colors.white;
    const titleColor = Colors.black;
    const subtitleColor = Colors.black87;
    const numberColor = Colors.black;
    const iconColor = Colors.black;
    const double titleSize = 18;
    const double subtitleSize = 13;
    const double numberSize = 15;
    const double iconSize = 22;

    return SafeArea(
      bottom: true,
      child: Container(
        color: bgColor,
        child: Column(
          children: [
            // Header row with back arrow and centered title
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, size: iconSize),
                    color: iconColor,
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'back'.tr(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'EMERGENCY HOTLINE NUMBERS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: titleSize,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dagupan City',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // symmetry spacer
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 6),

            const Divider(color: Colors.black12, height: 1),

            // Expanded list
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                itemCount: _services.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.black12, height: 12),
                itemBuilder: (context, index) {
                  final s = _services[index];
                  return _ServiceRow(
                    title: s['title']!,
                    subtitle: s['subtitle']!,
                    numbers: s['numbers']!,
                    primary: s['primary']!,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    numberColor: numberColor,
                    iconColor: iconColor,
                    titleSize: titleSize,
                    subtitleSize: subtitleSize,
                    numberSize: numberSize,
                    iconSize: iconSize,
                    onCall: (num) => _callNumber(context, num),
                    onSms: (num) => _sendSms(context, num),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String numbers;
  final String primary;
  final void Function(String) onCall;
  final void Function(String) onSms;

  final Color titleColor;
  final Color subtitleColor;
  final Color numberColor;
  final Color iconColor;
  final double titleSize;
  final double subtitleSize;
  final double numberSize;
  final double iconSize;

  const _ServiceRow({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.numbers,
    required this.primary,
    required this.onCall,
    required this.onSms,
    required this.titleColor,
    required this.subtitleColor,
    required this.numberColor,
    required this.iconColor,
    required this.titleSize,
    required this.subtitleSize,
    required this.numberSize,
    required this.iconSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: titleSize,
                    )),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: TextStyle(
                        color: subtitleColor, fontSize: subtitleSize)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(numbers,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: numberColor,
                      fontWeight: FontWeight.bold,
                      fontSize: numberSize,
                    )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.call, size: iconSize),
                      color: iconColor,
                      onPressed: () => onCall(primary),
                      tooltip: 'call'.tr(),
                    ),
                    IconButton(
                      icon: Icon(Icons.message, size: iconSize),
                      color: iconColor,
                      onPressed: () => onSms(primary),
                      tooltip: 'message'.tr(),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
