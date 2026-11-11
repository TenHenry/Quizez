import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizez/logic/auth/auth_bloc.dart';
import 'package:quizez/logic/auth/auth_event.dart';
import 'package:quizez/logic/auth/auth_state.dart';
import 'package:quizez/presentation/auth/widgets/login_form.dart';
import 'package:quizez/presentation/auth/widgets/register_form.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  late MockAuthBloc bloc;

  setUpAll(() => registerFallbackValue(FakeAuthEvent()));

  setUp(() {
    bloc = MockAuthBloc();
    when(() => bloc.state).thenReturn(const Unauthenticated());
    when(() => bloc.stream).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  Widget host(Widget child) => MaterialApp(
        home: BlocProvider<AuthBloc>.value(value: bloc, child: Scaffold(body: child)),
      );

  group('LoginForm', () {
    testWidgets('shows validation errors and sends nothing when the fields are empty', (tester) async {
      await tester.pumpWidget(host(const LoginForm()));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Enter your e-mail address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('rejects a malformed e-mail', (tester) async {
      await tester.pumpWidget(host(const LoginForm()));

      await tester.enterText(find.widgetWithText(TextField, 'email@domain.com'), 'not-an-email');
      await tester.enterText(find.widgetWithText(TextField, 'password'), 'secret123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Enter a valid e-mail address'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('sends the login event for valid data', (tester) async {
      await tester.pumpWidget(host(const LoginForm()));

      await tester.enterText(find.widgetWithText(TextField, 'email@domain.com'), 'anna@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'password'), 'secret123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      final event = verify(() => bloc.add(captureAny())).captured.single as LoginWithEmailPressed;
      expect(event.email, 'anna@example.com');
      expect(event.password, 'secret123');
    });

    testWidgets('has a Google button and a way to the registration', (tester) async {
      await tester.pumpWidget(host(const LoginForm()));

      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.ensureVisible(find.textContaining('Sign up'));
      await tester.tap(find.textContaining('Sign up'));
      verify(() => bloc.add(any(that: isA<ToggleAuthMode>()))).called(1);
    });
  });

  group('RegisterForm', () {
    testWidgets('shows errors for a short nickname, weak password and different passwords', (tester) async {
      await tester.pumpWidget(host(const RegisterForm()));

      await tester.enterText(find.widgetWithText(TextField, 'nickname'), 'ab');
      await tester.enterText(find.widgetWithText(TextField, 'email'), 'anna@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'password'), 'short');
      await tester.enterText(find.widgetWithText(TextField, 'confirm password'), 'different');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.pump();

      expect(find.text('Use 3-20 characters'), findsOneWidget);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('sends the sign-up event for valid data', (tester) async {
      await tester.pumpWidget(host(const RegisterForm()));

      await tester.enterText(find.widgetWithText(TextField, 'nickname'), 'anna_01');
      await tester.enterText(find.widgetWithText(TextField, 'email'), 'anna@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'password'), 'secret123');
      await tester.enterText(find.widgetWithText(TextField, 'confirm password'), 'secret123');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.pump();

      final event = verify(() => bloc.add(captureAny())).captured.single as SignUpWithEmailPressed;
      expect(event.nickname, 'anna_01');
      expect(event.email, 'anna@example.com');
    });
  });
}
