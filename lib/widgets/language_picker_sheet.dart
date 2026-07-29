import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Display names for supported app locales (language picker).
const Map<String, String> kAppLocaleDisplayNames = {
  'en': 'English',
  'es': 'Español',
  'hi': 'हिंदी',
  'bn': 'বাংলা',
  'te': 'తెలుగు',
  'ta': 'தமிழ்',
  'gu': 'ગુજરાતી',
  'mr': 'मराठी',
};

String appLocaleDisplayName(String code) =>
    kAppLocaleDisplayNames[code] ?? code;

/// Shows the same language bottom sheet used on Home and Quick Check.
void showAppLanguagePicker(
  BuildContext context,
  void Function(Locale locale) onLocaleChanged,
) {
  final l10n = AppLocalizations.of(context)!;
  final currentLocale = Localizations.localeOf(context);
  final supported = AppLocalizations.supportedLocales.toList();
  final others = supported
      .where((l) => l.languageCode != currentLocale.languageCode)
      .toList()
    ..sort((a, b) => appLocaleDisplayName(a.languageCode)
        .toLowerCase()
        .compareTo(appLocaleDisplayName(b.languageCode).toLowerCase()));

  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                appLocaleDisplayName(currentLocale.languageCode),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l10n.currentLanguage),
              enabled: false,
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                children: others.map((locale) {
                  final name = appLocaleDisplayName(locale.languageCode);
                  return ListTile(
                    title: Text(name),
                    onTap: () {
                      onLocaleChanged(locale);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
