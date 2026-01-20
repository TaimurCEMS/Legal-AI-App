import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_ai_app/features/common/widgets/buttons/primary_button.dart';
import 'package:legal_ai_app/features/common/widgets/buttons/secondary_button.dart';
import 'package:legal_ai_app/features/common/widgets/text_fields/app_text_field.dart';
import 'package:legal_ai_app/features/common/widgets/loading/loading_spinner.dart';
import 'package:legal_ai_app/features/common/widgets/empty_state/empty_state_widget.dart';

void main() {
  group('UI Components Tests', () {
    testWidgets('PrimaryButton displays label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('PrimaryButton calls onPressed when tapped', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Test Button',
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Test Button'));
      await tester.pump();

      expect(wasPressed, isTrue);
    });

    testWidgets('PrimaryButton shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Test Button',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SecondaryButton displays label', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondaryButton(
              label: 'Secondary Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secondary Button'), findsOneWidget);
    });

    testWidgets('AppTextField displays label and hint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Email',
              hint: 'Enter your email',
              controller: TextEditingController(),
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('LoadingSpinner displays message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingSpinner(
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EmptyStateWidget displays title and message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.folder_open,
              title: 'No Cases',
              message: 'Create your first case',
            ),
          ),
        ),
      );

      expect(find.text('No Cases'), findsOneWidget);
      expect(find.text('Create your first case'), findsOneWidget);
    });
  });
}
