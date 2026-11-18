import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StreakService {
  final SupabaseClient _client = Supabase.instance.client;

  // IMPORTANT:
  // We will make the Kotlin MethodChannel use this exact same name.
  static const MethodChannel _channel = MethodChannel(
    'com.example.upsc_preparation_app/widget',
  );

  /// Record today's study activity for the currently signed-in user.
  ///
  /// The Supabase function must derive the user from auth.uid().
  /// Returns true if a new study day was recorded.
  Future<bool> recordActivity() async {
    try {
      final result = await _client.rpc('record_study_day');

      if (result is bool) {
        return result;
      }

      debugPrint('Unexpected record_study_day response: $result');
      return false;
    } catch (e) {
      debugPrint('recordActivity error: $e');
      return false;
    }
  }

  /// Fetch current streak, longest streak and today's study status.
  Future<Map<String, dynamic>> fetchStudentStreaks() async {
    try {
      final result = await _client.rpc('fetch_student_streaks');

      if (result is! List || result.isEmpty) {
        return {'current': 0, 'longest': 0, 'todayRecorded': false};
      }

      final row = Map<String, dynamic>.from(result.first as Map);

      return {
        'current': (row['current_streak'] as num?)?.toInt() ?? 0,
        'longest': (row['longest_streak'] as num?)?.toInt() ?? 0,
        'todayRecorded': row['today_recorded'] == true,
      };
    } catch (e) {
      debugPrint('fetchStudentStreaks error: $e');

      return {'current': 0, 'longest': 0, 'todayRecorded': false};
    }
  }

  /// Fetch the total number of successfully completed tests.
  Future<int> fetchStudentTestCount() async {
    try {
      final result = await _client.rpc('fetch_student_test_count');

      if (result is num) {
        return result.toInt();
      }

      debugPrint('Unexpected fetch_student_test_count response: $result');
      return 0;
    } catch (e) {
      debugPrint('fetchStudentTestCount error: $e');
      return 0;
    }
  }

  /// Refresh the Android Home Screen widget.
  Future<void> updateWidgetCache() async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        await clearWidgetCache();
        return;
      }

      final streak = await fetchStudentStreaks();
      final testCount = await fetchStudentTestCount();

      // Do not write old user's data after logout or account switching.
      if (_client.auth.currentUser?.id != userId) {
        return;
      }

      await _channel.invokeMethod('updateWidgetData', {
        'currentStreak': streak['current'],
        'longestStreak': streak['longest'],
        'todayRecorded': streak['todayRecorded'],
        'testCount': testCount,
      });
    } catch (e) {
      debugPrint('updateWidgetCache error: $e');
    }
  }

  /// Clear widget data when the user signs out.
  Future<void> clearWidgetCache() async {
    try {
      await _channel.invokeMethod('clearWidgetData');
    } catch (e) {
      debugPrint('clearWidgetCache error: $e');
    }
  }
}
