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

// Error
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}