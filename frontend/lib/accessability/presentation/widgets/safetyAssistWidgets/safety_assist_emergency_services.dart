import 'package:AccessAbility/accessability/presentation/widgets/safetyAssistWidgets/design_service_row.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class SafetyAssistEmergencyServices extends StatelessWidget {
  const SafetyAssistEmergencyServices({Key? key}) : super(key: key);

  // Full services list
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

  /// Map a service title to an asset path.
  /// Make sure these filenames match your assets exactly (case-sensitive on some platforms).
  String _assetForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('pnp') || t.contains('police'))
      return 'assets/images/emergencyservices/police_station.png';
    if (t.contains('bfp') || t.contains('fire'))
      return 'assets/images/emergencyservices/bfp_dagupan.png';
    if (t.contains('red') || t.contains('cross'))
      return 'assets/images/emergencyservices/red_cross.png';
    if (t.contains('health') || t.contains('city health'))
      return 'assets/images/emergencyservices/city_health.png';
    if (t.contains('disaster') || t.contains('cdrrmo'))
      return 'assets/images/emergencyservices/cdrrmo.png';
    if (t.contains('social') || t.contains('cswd'))
      return 'assets/images/emergencyservices/cswd.png';
    if (t.contains('poso'))
      return 'assets/images/emergencyservices/poso_dagupan.png';
    if (t.contains('panda'))
      return 'assets/images/emergencyservices/panda_volunteer.png';
    if (t.contains('ofw'))
      return 'assets/images/emergencyservices/ofw_desk.png';
    if (t.contains('anti') || t.contains('vawc'))
      return 'assets/images/emergencyservices/anti_vawc.png';
    // fallback
    return 'assets/images/emergencyservices/support.png';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // header red for light mode, slightly darker red for dark mode
    final Color headerRed =
        isDarkMode ? const Color(0xFF8B0000) : const Color(0xFFD32F2F);
    // scaffold background adapts to theme but keep light-ish for content in light mode
    final Color scaffoldBg =
        isDarkMode ? Colors.grey[900]! : const Color(0xFFF2F6FA);

    const titleColor = Colors.black;
    const subtitleColor = Colors.black54;
    const numberColor = Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: BoxDecoration(
            color: headerRed,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white, // white on red appbar
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'emergency_contacts'.tr().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dagupan_city'.tr(),
                        style: const TextStyle(
                          color: Color.fromARGB(200, 255, 255, 255),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48), // keep symmetric spacing
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: scaffoldBg,
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _services.isEmpty
                  ? Center(
                      child: Text(
                        'no_contacts'.tr(),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _services.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Color(0xFFF0F0F0), height: 20),
                      itemBuilder: (context, index) {
                        final s = _services[index];
                        final asset = _assetForTitle(s['title'] ?? '');
                        return DesignServiceRow(
                          assetPath: asset,
                          fallbackIcon: Icons.support_agent,
                          title: s['title'] ?? '',
                          subtitle: s['subtitle'] ?? '',
                          numbers: s['numbers'] ?? '',
                          primary: s['primary'] ?? '',
                          onCall: (num) => _callNumber(context, num),
                          onSms: (num) => _sendSms(context, num),
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          numberColor: numberColor,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
