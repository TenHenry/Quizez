import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

// Pre-Login
class Unauthenticated extends AuthState {
  final bool isRegistering; // true = Sign Up, false = Log In
  const Unauthenticated({this.isRegistering = false});

  @override
  List<Object?> get props => [isRegistering];
}

// Post-Login
class Authenticated extends AuthState {
  final String userId;
  const Authenticated(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// The user opened a password reset link and must now choose a new password.
class PasswordRecovery extends AuthState {}

// Error
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Informational message (e.g. "reset link sent"); the bloc follows it with [Unauthenticated].
class AuthMessage extends AuthState {
  final String message;
  const AuthMessage(this.message);

  @override
  List<Object?> get props => [message];
}
