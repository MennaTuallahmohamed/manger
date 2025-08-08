import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationManager {
  static final TranslationManager _instance = TranslationManager._internal();
  factory TranslationManager() => _instance;
  TranslationManager._internal();

  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'ar';

  
  Future<void> initialize(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey) ?? _defaultLanguage;
    
    if (savedLanguage == 'ar') {
      await context.setLocale(const Locale('ar'));
    } else {
      await context.setLocale(const Locale('en'));
    }
  }

  Future<void> toggleLanguage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentLocale = context.locale.languageCode;
    final newLanguage = currentLocale == 'ar' ? 'en' : 'ar';
    
    await prefs.setString(_languageKey, newLanguage);
    
    if (newLanguage == 'ar') {
      await context.setLocale(const Locale('ar'));
    } else {
      await context.setLocale(const Locale('en'));
    }
  }

  
  String getCurrentLanguage(BuildContext context) {
    return context.locale.languageCode;
  }

  
  String getLanguageName(BuildContext context) {
    final language = getCurrentLanguage(context);
    return language == 'ar' ? 'العربية' : 'English';
  }

  Widget buildLanguageToggleButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language, color: Colors.blue),
      onPressed: () => toggleLanguage(context),
      tooltip: 'language'.tr(),
    );
  }

  Widget buildLanguageSelector(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.blue),
      onSelected: (String language) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_languageKey, language);
        
        if (language == 'ar') {
          await context.setLocale(const Locale('ar'));
        } else {
          await context.setLocale(const Locale('en'));
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'ar',
          child: Row(
            children: [
              const Text('🇪🇬'),
              const SizedBox(width: 8),
              const Text('العربية'),
              if (getCurrentLanguage(context) == 'ar')
                const Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              const Text('🇺🇸'),
              const SizedBox(width: 8),
              const Text('English'),
              if (getCurrentLanguage(context) == 'en')
                const Icon(Icons.check, color: Colors.green, size: 16),
            ],
          ),
        ),
      ],
    );
  }
} 