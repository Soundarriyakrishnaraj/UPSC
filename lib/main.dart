import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'registration_screen.dart';
import 'password_reset_screen.dart';
import 'core/theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rhuednmdoygnoxuyfvbc.supabase.co',
    publishableKey: 'sb_publishable_FUKlY8XfheOysBr_bVtp0w_y4Bk0aJ3',
  );

  runApp(const UPSCApp());
}

class UPSCApp extends StatefulWidget {
  const UPSCApp({super.key});

  @override
  State<UPSCApp> createState() => _UPSCAppState();
}

class _UPSCAppState extends State<UPSCApp> {
  late final StreamSubscription<AuthState> authSubscription;

  bool isOpeningRecoveryScreen = false;

  @override
  void initState() {
    super.initState();

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (authState) {
        if (authState.event == AuthChangeEvent.passwordRecovery &&
            !isOpeningRecoveryScreen) {
          final navigator = appNavigatorKey.currentState;

          if (navigator != null) {
            isOpeningRecoveryScreen = true;

            navigator
                .push(
                  MaterialPageRoute<void>(
                    builder: (context) => const PasswordResetScreen(),
                  ),
                )
                .whenComplete(() {
                  isOpeningRecoveryScreen = false;
                });
          }
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Authentication event error: $error');
      },
    );
  }

  @override
  void dispose() {
    authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'UPSC Preparation',
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}

// --------------------------------------------------
// WELCOME PAGE COLOURS
// --------------------------------------------------

class WelcomeColors {
  static const Color background = Color(0xFFF5F3F8);
  static const Color primary = Color(0xFF1E1D23);
  static const Color accent = Color(0xFFDCB8C2);
  static const Color secondary = Color(0xFFA58F99);
  static const Color surface = Color(0xFFFFFFFF);
}

// --------------------------------------------------
// SUPPORTED LANGUAGES
// --------------------------------------------------

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

const List<AppLanguage> supportedLanguages = [
  AppLanguage(code: 'as', name: 'Assamese', nativeName: 'অসমীয়া'),
  AppLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
  AppLanguage(code: 'brx', name: 'Bodo', nativeName: 'बड़ो'),
  AppLanguage(code: 'doi', name: 'Dogri', nativeName: 'डोगरी'),
  AppLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  AppLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  AppLanguage(code: 'ks', name: 'Kashmiri', nativeName: 'کٲشُر'),
  AppLanguage(code: 'kok', name: 'Konkani', nativeName: 'कोंकणी'),
  AppLanguage(code: 'mai', name: 'Maithili', nativeName: 'मैथिली'),
  AppLanguage(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  AppLanguage(code: 'mni', name: 'Manipuri', nativeName: 'ꯃꯩꯇꯩꯂꯣꯟ'),
  AppLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  AppLanguage(code: 'ne', name: 'Nepali', nativeName: 'नेपाली'),
  AppLanguage(code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ'),
  AppLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  AppLanguage(code: 'sa', name: 'Sanskrit', nativeName: 'संस्कृतम्'),
  AppLanguage(code: 'sat', name: 'Santhali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ'),
  AppLanguage(code: 'sd', name: 'Sindhi', nativeName: 'سنڌي'),
  AppLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  AppLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  AppLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
];

// --------------------------------------------------
// WELCOME / OPENING SCREEN
// --------------------------------------------------

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String selectedLanguage = 'en';

  AppLanguage get currentLanguage {
    return supportedLanguages.firstWhere(
      (language) => language.code == selectedLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WelcomeColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // APP LOGO
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: WelcomeColors.accent,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 58,
                      color: WelcomeColors.primary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TAGLINE
                  const Text(
                    'YOUR UPSC JOURNEY STARTS HERE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 2,
                      color: WelcomeColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // APP NAME
                  const Text(
                    'UPSC Preparation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: WelcomeColors.primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // SUBTITLE
                  const Text(
                    'Learn. Practice. Improve. Achieve.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: WelcomeColors.secondary,
                    ),
                  ),

                  const SizedBox(height: 45),

                  // LANGUAGE SELECTION
                  DropdownButtonFormField<String>(
                    initialValue: selectedLanguage,
                    isExpanded: true,
                    dropdownColor: WelcomeColors.surface,
                    menuMaxHeight: 420,
                    style: const TextStyle(
                      color: WelcomeColors.primary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Choose your language',
                      labelStyle: const TextStyle(
                        color: WelcomeColors.secondary,
                      ),
                      prefixIcon: const Icon(
                        Icons.language_rounded,
                        color: WelcomeColors.secondary,
                      ),
                      filled: true,
                      fillColor: WelcomeColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: WelcomeColors.accent,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: WelcomeColors.secondary,
                          width: 2,
                        ),
                      ),
                    ),
                    items: supportedLanguages.map((language) {
                      return DropdownMenuItem<String>(
                        value: language.code,
                        child: Text(
                          language.nativeName,
                          textDirection:
                              language.code == 'ur' ||
                                  language.code == 'ks' ||
                                  language.code == 'sd'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedLanguage = value;
                        });

                        debugPrint(
                          'Selected language: ${currentLanguage.name}',
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 22),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WelcomeColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // CREATE ACCOUNT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegistrationScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: WelcomeColors.primary,
                        backgroundColor: WelcomeColors.accent,
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(
                          color: WelcomeColors.accent,
                          width: 1.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // FOOTER
                  const Text(
                    'Your preparation. Your progress. Your future.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: WelcomeColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
