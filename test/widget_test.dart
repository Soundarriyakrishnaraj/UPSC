import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_preparation_app/main.dart';

void main() {
  testWidgets('UPSC welcome screen displays correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UPSCApp());

    expect(find.text('UPSC Preparation'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
