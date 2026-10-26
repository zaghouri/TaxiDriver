import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// Current UI language. Persists the user's choice (D29).
///
/// Default before any choice: phone language if ar/fr/en, otherwise French.
class LocaleController extends ChangeNotifier {
  LocaleController(this._prefs, {String? systemLanguageCode})
      : _system = systemLanguageCode ?? ui.PlatformDispatcher.instance.locale.languageCode {
    final saved = _prefs.getString(prefsKey);
    _chosen = saved != null && kSupportedLanguageCodes.contains(saved);
    _code = _chosen ? saved! : defaultFor(_system);
  }

  static const prefsKey = 'ridema.locale';

  final SharedPreferences _prefs;
  final String _system;
  late String _code;
  late bool _chosen;

  /// `ar`, `fr` or `en`.
  String get languageCode => _code;
  Locale get locale => Locale(_code);
  bool get isRtl => _code == 'ar';

  /// False until the user picked a language (first launch shows the picker).
  bool get hasChosen => _chosen;

  static String defaultFor(String systemCode) => kSupportedLanguageCodes.contains(systemCode) ? systemCode : 'fr';

  Future<void> setLanguage(String code) async {
    if (!kSupportedLanguageCodes.contains(code)) return;
    final changed = code != _code || !_chosen;
    _code = code;
    _chosen = true;
    await _prefs.setString(prefsKey, code);
    if (changed) notifyListeners();
  }
}
