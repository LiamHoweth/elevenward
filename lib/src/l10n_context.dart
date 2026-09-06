import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

extension LocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String contentLocale(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'pt') return 'pt-BR';
  return switch (locale.languageCode) {
    'es' => 'es',
    'fr' => 'fr',
    _ => 'en',
  };
}
