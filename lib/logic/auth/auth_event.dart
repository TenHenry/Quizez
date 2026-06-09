import 'package:equatable/equatable.dart';

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

// Other
class GoogleSignInPressed extends AuthEvent {}
class AppleSignInPressed extends AuthEvent {}