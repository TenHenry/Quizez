import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

// Log - Register
class ToggleAuthMode extends AuthEvent {}

class LoginWithEmailPressed extends AuthEvent {
  final String email;
  final String password;
  const LoginWithEmailPressed(this.email, this.password);
}

class SignUpWithEmailPressed extends AuthEvent {
  final String nickname;
  final String email;
  final String password;
  const SignUpWithEmailPressed(this.nickname, this.email, this.password);
}

class LogoutRequested extends AuthEvent {}

// Other providers
class GoogleSignInPressed extends AuthEvent {}

class AppleSignInPressed extends AuthEvent {}

// Password reset
class PasswordResetRequested extends AuthEvent {
  final String email;
  const PasswordResetRequested(this.email);
}

class PasswordUpdateRequested extends AuthEvent {
  final String newPassword;
  const PasswordUpdateRequested(this.newPassword);
}

/// Internal: Supabase reported a session change (Google sign-in, recovery link, expired session).
class AuthSessionChanged extends AuthEvent {
  final AuthChangeEvent event;
  final Session? session;
  const AuthSessionChanged(this.event, this.session);

  @override
  List<Object?> get props => [event, session?.user.id];
}
