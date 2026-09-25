import 'package:dizzo/core/l10n/app_language.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Tests run in Uzbek (the source language).
const testLocale = Locale('uz');

final uzL10n = lookupAppLocalizations(testLocale);

const l10nDelegates = AppLocalizations.localizationsDelegates;
const l10nLocales = AppLocalizations.supportedLocales;

/// Date symbols for unit tests that format dates without pumping an app.
Future<void> initTestDates() => initializeDateFormatting();
