import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'screens/papers_screen.dart';
import 'screens/admin/admin_papers_screen.dart';
import 'screens/destination_screen.dart';
import 'screens/result_screen.dart';
import 'services/papers_service.dart';
import 'services/test_service.dart';
import 'services/pdf_report_service.dart';
import 'models/test_model.dart';
import 'main.dart';

// Language names shown in their respective scripts.
// The keys are saved in Supabase; the values are shown to students.
const Map<String, String> appLanguages = {
  'Assamese': 'অসমীয়া',
  'Bengali': 'বাংলা',
  'Bodo': 'बड़ो',
  'Dogri': 'डोगरी',
  'English': 'English',
  'Gujarati': 'ગુજરાતી',
  'Hindi': 'हिन्दी',
  'Kannada': 'ಕನ್ನಡ',
  'Kashmiri': 'کٲشُر',
  'Konkani': 'कोंकणी',
  'Maithili': 'मैथिली',
  'Malayalam': 'മലയാളം',
  'Manipuri': 'মৈতৈলোন্',
  'Marathi': 'मराठी',
  'Nepali': 'नेपाली',
  'Odia': 'ଓଡ଼ିଆ',
  'Punjabi': 'ਪੰਜਾਬੀ',
  'Sanskrit': 'संस्कृतम्',
  'Santhali': 'ᱥᱟᱱᱛᱟᱲᱤ',
  'Sindhi': 'سنڌي',
  'Tamil': 'தமிழ்',
  'Telugu': 'తెలుగు',
  'Urdu': 'اردو',
};

String languageDisplayName(String language) {
  return appLanguages[language] ?? language;
}

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int selectedIndex = 0;
  bool showQuoteScreen = true;
  Timer? quoteTimer;
  bool isAdmin = false;

  final List<String> quotes = [
    'Success is the sum of small efforts repeated day in and day out.',
    'The future depends on what you do today.',
    'Dream big, work hard, stay focused and never give up.',
    'Your dedication today creates your success tomorrow.',
    'Great things are done by a series of small things brought together.',
    'A journey of a thousand miles begins with a single step.',
  ];

  late final String dailyQuote;

  String get studentName {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final name = metadata?['full_name']?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Student';
  }

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();

    dailyQuote = quotes[Random().nextInt(quotes.length)];

    quoteTimer = Timer(const Duration(seconds: 35), () {
      if (mounted) {
        setState(() {
          showQuoteScreen = false;
        });
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdministrator = await PapersService().checkIsAdmin();
      if (mounted) {
        setState(() {
          isAdmin = isAdministrator;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    quoteTimer?.cancel();
    super.dispose();
  }

  void closeQuoteScreen() {
    quoteTimer?.cancel();
    setState(() {
      showQuoteScreen = false;
    });
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to log out: $error')));
    }
  }

  void openTab(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(
        studentName: studentName,
        onOpenTab: openTab,
        isAdmin: isAdmin,
      ),
      const StudentPapersScreen(),
      const _DestinationTab(),
      _ProfileTab(onLogout: logout, isAdmin: isAdmin),
    ];

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(index: selectedIndex, children: pages),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: openTab,
            backgroundColor: AppTheme.softRose,
            indicatorColor: AppTheme.cherryBlossom,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'Papers',
              ),
              NavigationDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag_rounded),
                label: 'Destination',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
        if (showQuoteScreen)
          Positioned.fill(
            child: _DailyQuoteScreen(
              quote: dailyQuote,
              onContinue: closeQuoteScreen,
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------
// DAILY QUOTE
// --------------------------------------------------

class _DailyQuoteScreen extends StatelessWidget {
  final String quote;
  final VoidCallback onContinue;

  const _DailyQuoteScreen({required this.quote, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.winePlum,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 85,
                    width: 85,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.pastelPink,
                      size: 43,
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'A NEW DAY. A NEW OPPORTUNITY.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.pastelPink,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Your Daily Inspiration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Icon(
                    Icons.format_quote_rounded,
                    color: AppTheme.pastelPink,
                    size: 55,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    quote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    width: 55,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.cherryBlossom,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'Believe in your preparation.\nBelieve in your purpose.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 45),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.pastelPink,
                        foregroundColor: AppTheme.winePlum,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Continue to Dashboard',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'Your dashboard will open automatically in 35 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
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

// --------------------------------------------------
// HOME TAB
// --------------------------------------------------

class _HomeTab extends StatefulWidget {
  final String studentName;
  final ValueChanged<int> onOpenTab;
  final bool isAdmin;

  const _HomeTab({
    required this.studentName,
    required this.onOpenTab,
    this.isAdmin = false,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _testSvc = TestService();
  Map<String, dynamic> _stats = {};
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await _testSvc.fetchHomeStats();
      if (mounted) setState(() { _stats = s; _statsLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.studentName.split(' ').first;
    final count     = (_stats['count'] as num? ?? 0).toInt();
    final best      = (_stats['bestScore'] as num? ?? 0.0).toDouble();
    final avg       = (_stats['avgScore'] as num? ?? 0.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 700 ? 40.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 22,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UPSC PREPARATION',
                              style: TextStyle(
                                color: AppTheme.winePlum,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hello, $firstName!',
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.winePlum,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Your journey to serve the nation starts here.',
                              style: TextStyle(
                                color: AppTheme.dustyMauve,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppTheme.winePlum,
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Admin Panel',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminPapersScreen(),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: AppTheme.pastelPink,
                              child: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: AppTheme.winePlum,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(23),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.winePlum, Color(0xFF5D3039)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.winePlum.withValues(alpha: 0.20),
                          blurRadius: 15,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'YOUR DREAM. YOUR DESTINATION.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Prepare today.\nLead tomorrow.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Every question you practise brings you one step closer to your goal.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => widget.onOpenTab(2),
                          icon: const Icon(Icons.flag_rounded),
                          label: const Text('Explore Destination'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.winePlum,
                            backgroundColor: AppTheme.pastelPink,
                            side: const BorderSide(color: AppTheme.pastelPink),
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    title: 'Your preparation',
                    subtitle: 'Your learning journey at a glance',
                  ),
                  const SizedBox(height: 13),
                  LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth >= 700 ? 4 : 2;
                      final stats = [
                        _StatCard(
                          icon: Icons.quiz_outlined,
                          title: 'Tests taken',
                          value: _statsLoaded ? '$count' : '…',
                          note: count == 0 ? 'Complete your first test' : '$count completed',
                        ),
                        _StatCard(
                          icon: Icons.emoji_events_outlined,
                          title: 'Best score',
                          value: _statsLoaded && count > 0 ? '${best.toStringAsFixed(1)}%' : '--',
                          note: 'Your highest score',
                        ),
                        _StatCard(
                          icon: Icons.trending_up_rounded,
                          title: 'Avg score',
                          value: _statsLoaded && count > 0 ? '${avg.toStringAsFixed(1)}%' : '0%',
                          note: 'Keep learning',
                        ),
                        _StatCard(
                          icon: Icons.local_fire_department_outlined,
                          title: 'Study streak',
                          value: '0 days',
                          note: 'Build your habit',
                        ),
                      ];

                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 2 ? 1.35 : 0.95,
                        children: stats,
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  const _SectionHeader(
                    title: 'Know your goal',
                    subtitle: 'Tap a question to discover the answer',
                  ),
                  const SizedBox(height: 13),
                  const _FaqItem(
                    question: 'What is UPSC?',
                    answer: 'The Union Public Service Commission (UPSC) is a constitutional body responsible for conducting examinations to recruit candidates for various services and posts under the Government of India.',
                  ),
                  const _FaqItem(
                    question: 'What is the Civil Services Examination?',
                    answer: 'The Civil Services Examination is a national-level competitive examination conducted by UPSC to recruit candidates for services such as the Indian Administrative Service (IAS), Indian Police Service (IPS) and Indian Foreign Service (IFS), among others.',
                  ),
                  const _FaqItem(
                    question: 'Why should I prepare for UPSC?',
                    answer: 'Civil services offer opportunities to contribute to public administration, policy implementation, development and the welfare of citizens.',
                  ),
                  const _FaqItem(
                    question: 'What are the stages of the UPSC CSE?',
                    answer: 'The Civil Services Examination has three stages: Preliminary Examination, Main Examination and Personality Test (Interview). Candidates must qualify at each stage to progress.',
                  ),
                  const _FaqItem(
                    question: 'What responsibilities do civil servants have?',
                    answer: 'Civil servants help implement government policies, administer public services, maintain law and order in their respective roles, and support development and public welfare.',
                  ),
                  const SizedBox(height: 25),
                  const Center(
                    child: Text(
                      'Learn with purpose. Serve with pride.',
                      style: TextStyle(
                        color: AppTheme.winePlum,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------
// SECTION HEADER
// --------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppTheme.winePlum,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
        ),
      ],
    );
  }
}

// --------------------------------------------------
// STAT CARD
// --------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String note;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppTheme.winePlum, size: 22),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: AppTheme.winePlum,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.winePlum,
            ),
          ),
          Text(
            note,
            style: const TextStyle(fontSize: 10, color: AppTheme.dustyMauve),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// EXPANDABLE QUESTION
// --------------------------------------------------

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: AppTheme.cherryBlossom.withValues(alpha: 0.15),
        ),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.winePlum,
              size: 27,
            ),
          ),
          title: Text(
            widget.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.winePlum,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.answer,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppTheme.dustyMauve,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// DESTINATION TAB
// --------------------------------------------------

class _DestinationTab extends StatelessWidget {
  const _DestinationTab();

  @override
  Widget build(BuildContext context) {
    return const DestinationScreen();
  }
}

// --------------------------------------------------
// PROFILE TAB
// --------------------------------------------------

class _ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isAdmin;

  const _ProfileTab({required this.onLogout, this.isAdmin = false});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool isSaving = false;
  bool isUpdatingNotifications = false;
  String? loadError;

  User? get currentUser => supabase.auth.currentUser;

  String get email => currentUser?.email ?? 'Not available';

  String get fullName {
    final value = profile?['full_name']?.toString();
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }

    final metadata = currentUser?.userMetadata;
    final metadataName = metadata?['full_name']?.toString();
    if (metadataName != null && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }

    return 'Student';
  }

  String get username {
    final value = profile?['username']?.toString();
    if (value != null && value.isNotEmpty) return value;
    return 'Not available';
  }

  String get phone {
    final value = profile?['phone']?.toString();
    if (value != null && value.isNotEmpty) return value;
    return 'Not available';
  }

  String get preferredLanguage =>
      profile?['preferred_language']?.toString() ?? 'English';

  int get dailyGoal {
    final value = profile?['daily_study_goal_minutes'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 180;
  }

  bool get notificationsEnabled =>
      profile?['notifications_enabled'] as bool? ?? true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = 'Please sign in again to view your profile.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await supabase
          .from('profiles')
          .select(
            'full_name, phone, username, avatar_url, '
            'preferred_language, daily_study_goal_minutes, '
            'notifications_enabled',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        profile = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Unable to load your profile. Please try again.';
      });
    }
  }

  // Save notification preference immediately when the switch is changed.
  Future<void> updateNotifications(bool enabled) async {
    final user = currentUser;

    if (user == null || isUpdatingNotifications) return;

    final previousValue = notificationsEnabled;

    // Update the screen immediately.
    setState(() {
      profile = {...?profile, 'notifications_enabled': enabled};
      isUpdatingNotifications = true;
    });

    try {
      await supabase
          .from('profiles')
          .update({
            'notifications_enabled': enabled,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        isUpdatingNotifications = false;
      });

      _showMessage(
        enabled
            ? 'Notifications preference enabled.'
            : 'Notifications preference disabled.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        profile = {...?profile, 'notifications_enabled': previousValue};
        isUpdatingNotifications = false;
      });

      _showMessage('Could not update notifications: ${error.message}');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        profile = {...?profile, 'notifications_enabled': previousValue};
        isUpdatingNotifications = false;
      });

      _showMessage(
        'Unable to update notification preference. Please try again.',
      );
    }
  }

  Future<void> editProfile() async {
    if (profile == null) {
      _showMessage(
        'Your profile could not be loaded. Please refresh and try again.',
      );
      return;
    }

    final nameController = TextEditingController(text: fullName);
    final goalController = TextEditingController(text: dailyGoal.toString());

    String selectedLanguage = appLanguages.containsKey(preferredLanguage)
        ? preferredLanguage
        : 'English';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.alabasterGrey,
              title: const Text(
                'Edit profile',
                style: TextStyle(
                  color: AppTheme.winePlum,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full name',
                        style: TextStyle(
                          color: AppTheme.winePlum,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Preferred language',
                        style: TextStyle(
                          color: AppTheme.winePlum,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.language_rounded),
                        ),
                        items: appLanguages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              textDirection:
                                  entry.key == 'Urdu' ||
                                      entry.key == 'Sindhi' ||
                                      entry.key == 'Kashmiri'
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedLanguage = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Daily study goal (minutes)',
                        style: TextStyle(
                          color: AppTheme.winePlum,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: goalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'For example: 180',
                          prefixIcon: Icon(Icons.timer_outlined),
                          helperText: 'Choose between 15 and 1440 minutes.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final goal = int.tryParse(goalController.text.trim());

                    if (name.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid full name.'),
                        ),
                      );
                      return;
                    }

                    if (goal == null || goal < 15 || goal > 1440) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Study goal must be between 15 and 1440 minutes.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'full_name': name,
                      'preferred_language': selectedLanguage,
                      'daily_study_goal_minutes': goal,
                    });
                  },
                  child: const Text('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    goalController.dispose();

    if (result == null || !mounted) return;

    await saveProfileChanges(result);
  }

  Future<void> saveProfileChanges(Map<String, dynamic> changes) async {
    final user = currentUser;
    if (user == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      await supabase
          .from('profiles')
          .update({
            ...changes,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);

      if (!mounted) return;

      setState(() {
        profile = {...?profile, ...changes};
        isSaving = false;
      });

      _showMessage('Your profile has been updated successfully.');
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage('Could not save profile: ${error.message}');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage('Something went wrong while saving your profile.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.winePlum),
      );
    }

    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                color: AppTheme.dustyMauve,
                size: 48,
              ),
              const SizedBox(height: 15),
              Text(
                loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.winePlum),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final avatarUrl = profile?['avatar_url']?.toString();
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';

    return RefreshIndicator(
      color: AppTheme.winePlum,
      onRefresh: loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.winePlum,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Your account and preparation preferences',
                  style: TextStyle(fontSize: 13, color: AppTheme.dustyMauve),
                ),
                const SizedBox(height: 25),

                // STUDENT PROFILE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.winePlum, Color(0xFF5D3039)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.pastelPink,
                            backgroundImage:
                                avatarUrl != null &&
                                    avatarUrl.startsWith('http')
                                ? NetworkImage(avatarUrl)
                                : null,
                            child:
                                avatarUrl == null ||
                                    !avatarUrl.startsWith('http')
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: AppTheme.winePlum,
                                      fontSize: 35,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.cherryBlossom,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 17,
                              color: AppTheme.winePlum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelPink,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'UPSC Aspirant',
                          style: TextStyle(
                            color: AppTheme.winePlum,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSaving ? null : editProfile,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(isSaving ? 'Saving...' : 'Edit profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.pastelPink,
                            foregroundColor: AppTheme.winePlum,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const _SectionHeader(
                  title: 'Account details',
                  subtitle: 'Your registered information',
                ),
                const SizedBox(height: 13),
                _ProfileInfo(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: fullName,
                ),
                _ProfileInfo(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: username,
                ),
                _ProfileInfo(
                  icon: Icons.email_outlined,
                  label: 'Email address',
                  value: email,
                ),
                _ProfileInfo(
                  icon: Icons.phone_outlined,
                  label: 'Mobile number',
                  value: phone,
                ),

                const SizedBox(height: 25),

                const _SectionHeader(
                  title: 'Preparation preferences',
                  subtitle: 'Your personal study settings',
                ),
                const SizedBox(height: 13),
                _ProfileInfo(
                  icon: Icons.language_rounded,
                  label: 'Preferred language',
                  value: languageDisplayName(preferredLanguage),
                  textDirection:
                      preferredLanguage == 'Urdu' ||
                          preferredLanguage == 'Sindhi' ||
                          preferredLanguage == 'Kashmiri'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
                _ProfileInfo(
                  icon: Icons.timer_outlined,
                  label: 'Daily study goal',
                  value:
                      '${(dailyGoal / 60).toStringAsFixed(dailyGoal % 60 == 0 ? 0 : 1)} hours ($dailyGoal minutes)',
                ),

                // LIVE NOTIFICATION SWITCH
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.softRose,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppTheme.cherryBlossom),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: AppTheme.winePlum,
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.winePlum,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Receive study reminders and updates',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.dustyMauve,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUpdatingNotifications)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.winePlum,
                          ),
                        )
                      else
                        Switch(
                          value: notificationsEnabled,
                          onChanged: updateNotifications,
                          activeThumbColor: AppTheme.winePlum,
                          activeTrackColor: AppTheme.cherryBlossom,
                        ),
                    ],
                  ),
                ),

                // ── Test Performance section ──────────────────────
                const SizedBox(height: 25),
                const _SectionHeader(
                  title: 'Test Performance',
                  subtitle: 'Your examination history',
                ),
                const SizedBox(height: 13),
                _TestHistorySection(),

                if (widget.isAdmin) ...[
                  const SizedBox(height: 25),
                  const _SectionHeader(
                    title: 'Administration',
                    subtitle: 'Manage papers and application content',
                  ),
                  const SizedBox(height: 13),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminPapersScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.winePlum, Color(0xFF5D3039)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.winePlum.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.pastelPink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: AppTheme.winePlum,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Papers Admin Panel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Upload, publish and edit UPSC papers',
                                  style: TextStyle(
                                    color: AppTheme.pastelPink,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Center(
                  child: Text(
                    'Your journey. Your progress. Your destination.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.dustyMauve, fontSize: 11),
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

// --------------------------------------------------
// PROFILE INFORMATION TILE
// --------------------------------------------------

class _ProfileInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextDirection textDirection;

  const _ProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.textDirection = TextDirection.ltr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.softRose,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.winePlum),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.dustyMauve,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  textDirection: textDirection,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.winePlum,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// --------------------------------------------------
// TEST HISTORY SECTION (Profile)
// --------------------------------------------------

class _TestHistorySection extends StatefulWidget {
  const _TestHistorySection();

  @override
  State<_TestHistorySection> createState() => _TestHistorySectionState();
}

class _TestHistorySectionState extends State<_TestHistorySection> {
  final _svc = TestService();
  List<TestAttempt> _attempts = [];
  Map<String, TestModel> _testMap = {};
  bool _loading = true;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final attempts = await _svc.fetchMyAttempts(limit: 20);
      final tests = await _svc.fetchPublishedTests();
      if (!mounted) return;
      setState(() {
        _attempts = attempts;
        _testMap = {for (final t in tests) t.id: t};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    if (_attempts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.softRose,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cherryBlossom),
        ),
        child: const Column(children: [
          Icon(Icons.quiz_outlined, size: 36, color: AppTheme.cherryBlossom),
          SizedBox(height: 8),
          Text('No test attempts yet', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
          SizedBox(height: 4),
          Text('Complete a test from the Destination map', style: TextStyle(color: AppTheme.dustyMauve, fontSize: 12)),
        ]),
      );
    }

    return Column(
      children: _attempts.map((a) {
        final test = _testMap[a.testId];
        final pct = a.percentage?.toStringAsFixed(1) ?? '--';
        final marks = a.marksObtained?.toStringAsFixed(2) ?? '--';
        final date = a.submittedAt ?? a.startedAt;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      test?.title ?? 'Test',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.winePlum, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
                    Icon(i < a.starsEarned ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14, color: AppTheme.winePlum))),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${test?.subject ?? ''}  ·  Attempt #${a.attemptNumber}  ·  ${_fmtDate(date)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.dustyMauve),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _PillStat(label: 'Score', value: '$pct%'),
                  const SizedBox(width: 8),
                  _PillStat(label: 'Marks', value: marks),
                  const SizedBox(width: 8),
                  _PillStat(label: '✓', value: '${a.correctCount ?? 0}'),
                  const SizedBox(width: 8),
                  _PillStat(label: '✗', value: '${a.incorrectCount ?? 0}'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: test == null ? null : () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        test: test,
                        attemptId: a.id,
                        scoreResult: {
                          'correct': a.correctCount ?? 0,
                          'incorrect': a.incorrectCount ?? 0,
                          'unanswered': a.unansweredCount ?? 0,
                          'marks_obtained': a.marksObtained ?? 0.0,
                          'negative_marks': a.negativeMarks ?? 0.0,
                          'max_marks': a.maxMarks ?? 0.0,
                          'percentage': a.percentage ?? 0.0,
                          'stars': a.starsEarned,
                        },
                      ),
                    )),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: (test == null || _generatingPdf) ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _generatingPdf = true);
                      try {
                        final savedPath = await PdfReportService.savePdfToDownloads(
                          test: test,
                          attempt: a,
                          service: _svc,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('✓ Report saved to $savedPath'),
                            backgroundColor: AppTheme.winePlum,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                            SnackBar(content: Text('PDF error: $e'), backgroundColor: AppTheme.winePlum));
                      } finally {
                        if (mounted) setState(() => _generatingPdf = false);
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                    label: const Text('Report', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                  )),
                ]),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }
}

class _PillStat extends StatelessWidget {
  final String label;
  final String value;
  const _PillStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.alabasterGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cherryBlossom),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.winePlum)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.dustyMauve)),
      ]),
    );
  }
}
