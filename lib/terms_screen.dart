import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';

export 'home_screen.dart' show StudentHomeScreen;

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  static const String termsVersion = '1.0';

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController scrollController = ScrollController();

  bool hasReadToEnd = false;
  bool hasAccepted = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(checkScrollPosition);
  }

  void checkScrollPosition() {
    if (!scrollController.hasClients) return;

    final position = scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 20 && !hasReadToEnd) {
      setState(() {
        hasReadToEnd = true;
      });
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(checkScrollPosition);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> acceptTerms() async {
    if (!hasReadToEnd || !hasAccepted || isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Please log in again to continue.');
      }

      await supabase.from('terms_acceptances').insert({
        'user_id': user.id,
        'terms_version': TermsScreen.termsVersion,
      });

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const StudentHomeScreen()),
        (route) => false,
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save acceptance: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Color(0xFF174B45),
        ),
      ),
    );
  }

  Widget sectionText(String content) {
    return Text(
      content,
      style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF174B45);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F5),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFF7F8F5),
          title: const Text(
            'Terms & Conditions',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.school_rounded,
                          size: 65,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Center(
                        child: Text(
                          'UPSC Preparation',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Owned and operated by Plant Green Inertia',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Center(
                        child: Text(
                          'Terms & Conditions and Student Guidelines',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Center(
                        child: Text(
                          'Version 1.0',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),

                      sectionTitle('1. Account Registration'),
                      sectionText(
                        'Students must provide accurate and complete '
                        'information, including their full name, email '
                        'address and mobile number. Each student should '
                        'maintain only one account and keep their login '
                        'credentials confidential. Account credentials '
                        'must not be shared with others.',
                      ),

                      sectionTitle('2. Purpose of the Application'),
                      sectionText(
                        'UPSC Preparation is an educational application '
                        'designed to help students prepare for competitive '
                        'examinations through study materials, practice '
                        'tests, previous-year papers and learning resources. '
                        'The application is independently operated by '
                        'Plant Green Inertia and is not affiliated with '
                        'or endorsed by UPSC or the Government of India.',
                      ),

                      sectionTitle('3. Student Responsibilities'),
                      sectionText(
                        'Students agree to use the application lawfully '
                        'and responsibly. Students must not manipulate '
                        'test results, misuse the leaderboard, interfere '
                        'with application services, attempt unauthorized '
                        'access or submit unlawful or harmful content.',
                      ),

                      sectionTitle('4. Tests and Scores'),
                      sectionText(
                        'Students should attempt tests independently. '
                        'Scores, rankings and progress records are intended '
                        'to support learning and self-assessment. They do '
                        'not guarantee success, selection or employment '
                        'in any examination or service.',
                      ),

                      sectionTitle('5. Study Materials and Content'),
                      sectionText(
                        'Application-created content, questions, '
                        'explanations and designs may be protected by '
                        'intellectual property laws. Students must not '
                        'copy, sell, redistribute or commercially exploit '
                        'protected content without permission. Third-party '
                        'materials remain subject to their respective '
                        'copyright and usage conditions.',
                      ),

                      sectionTitle('6. Account Security'),
                      sectionText(
                        'Students are responsible for protecting their '
                        'accounts and passwords. Students should contact '
                        'the application support team if they suspect '
                        'unauthorized access. Accounts involved in misuse '
                        'or fraudulent activity may be restricted after '
                        'appropriate review and subject to applicable law.',
                      ),

                      sectionTitle('7. Privacy and Personal Information'),
                      sectionText(
                        'Information such as account details, test '
                        'attempts and learning progress may be processed '
                        'to provide application services. Personal '
                        'information will be handled according to the '
                        'application Privacy Policy and applicable law. '
                        'Students should review the Privacy Policy before '
                        'using the application.',
                      ),

                      sectionTitle('8. Availability and Changes'),
                      sectionText(
                        'Application features, content and services may '
                        'be updated, modified or temporarily unavailable. '
                        'These terms may also be revised. Students may '
                        'be asked to review and accept a new version when '
                        'the terms change.',
                      ),

                      sectionTitle('9. Educational Disclaimer'),
                      sectionText(
                        'The application is an independent preparation '
                        'resource. Students should consult official UPSC '
                        'notifications and websites for authoritative '
                        'information about eligibility, syllabus, '
                        'examination dates and rules. No examination '
                        'result or selection is guaranteed.',
                      ),

                      sectionTitle('10. Acceptance'),
                      sectionText(
                        'By selecting the acceptance checkbox and tapping '
                        'Accept & Continue, students confirm that they '
                        'have read and agree to these Terms & Conditions '
                        'and Student Guidelines.',
                      ),

                      const SizedBox(height: 25),
                      const Center(
                        child: Text(
                          'End of Terms & Conditions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7E5))),
                ),
                child: Column(
                  children: [
                    if (!hasReadToEnd)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Please scroll to the end to enable acceptance.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),

                    CheckboxListTile(
                      value: hasAccepted,
                      onChanged: hasReadToEnd
                          ? (value) {
                              setState(() {
                                hasAccepted = value ?? false;
                              });
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      title: const Text(
                        'I have read and agree to the Terms & Conditions.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: hasReadToEnd && hasAccepted && !isSaving
                            ? acceptTerms
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Accept & Continue',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
