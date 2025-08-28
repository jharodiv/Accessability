import 'package:accessability/accessability/presentation/screens/settings/settingsScreens/delete_account.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class AdditionalDataRights extends StatelessWidget {
  const AdditionalDataRights({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final Color primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final TextStyle headerStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: primaryTextColor,
    );
    final TextStyle bodyStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: primaryTextColor,
      height: 1.4,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            boxShadow: const [
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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'privacySecurity'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        color: isDarkMode ? Colors.black : Colors.white,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 25, top: 10),
                  child: Text(
                    'additionalDataRightsTitle'.tr(),
                    style: headerStyle,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'additionalDataRightsDescription'.tr(),
                            style: headerStyle.copyWith(fontSize: 18),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 30, right: 30, bottom: 20),
                          child: Text(
                            'additionalDataRightsContent'.tr(),
                            style: bodyStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DeleteAccount()),
                      );
                    },
                    title: Center(
                      child: Text(
                        'deleteAccountButton'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
