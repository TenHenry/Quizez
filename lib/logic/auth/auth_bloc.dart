import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/config.dart';
import '../../core/validators.dart';
import '../../data/services/profile_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _supabase = Supabase.instance.client;
  final ProfileService _profile;
  late final StreamSubscription<dynamic> _authSubscription;

  AuthBloc({ProfileService? profile})
      : _profile = profile ?? ProfileService(),
        super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<ToggleAuthMode>(_onToggleAuthMode);
    on<LoginWithEmailPressed>(_onLoginWithEmailPressed);
    on<SignUpWithEmailPressed>(_onSignUpWithEmailPressed);
    on<GoogleSignInPressed>(_onGoogleSignInPressed);
    on<PasswordResetRequested>(_onPasswordResetRequested);
    on<PasswordUpdateRequested>(_onPasswordUpdateRequested);
    on<AuthSessionChanged>(_onSessionChanged);
    on<LogoutRequested>(_onLogoutRequested);

    // Reacts to sessions that start outside of this bloc: Google sign-in and password recovery deep links.
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      add(AuthSessionChanged(data.event, data.session));
    });
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    return super.close();
  }

  // Loading Screen
  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(seconds: 2));

    final session = _supabase.auth.currentSession;
    if (session != null) {
      emit(Authenticated(session.user.id));
    } else {
      emit(const Unauthenticated(isRegistering: false));
    }
  }

  void _onToggleAuthMode(ToggleAuthMode event, Emitter<AuthState> emit) {
    if (state is Unauthenticated) {
      final current = state as Unauthenticated;
      emit(Unauthenticated(isRegistering: !current.isRegistering));
    }
  }

  Future<void> _onLoginWithEmailPressed(LoginWithEmailPressed event, Emitter<AuthState> emit) async {
    final error = Validators.email(event.email) ?? (event.password.isEmpty ? 'Enter your password' : null);
    if (error != null) {
      emit(AuthFailure(error));
      emit(const Unauthenticated(isRegistering: false));
      return;
    }

    emit(AuthLoading());
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: event.email.trim(),
        password: event.password,
      );
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(const Unauthenticated(isRegistering: false));
    }
  }

  Future<void> _onSignUpWithEmailPressed(SignUpWithEmailPressed event, Emitter<AuthState> emit) async {
    final error = Validators.nickname(event.nickname) ?? Validators.email(event.email) ?? Validators.password(event.password);
    if (error != null) {
      emit(AuthFailure(error));
      emit(const Unauthenticated(isRegistering: true));
      return;
    }

    emit(AuthLoading());
    try {
      if (!await _profile.isNicknameAvailable(event.nickname)) {
        emit(const AuthFailure('This nickname is already taken.'));
        emit(const Unauthenticated(isRegistering: true));
        return;
      }

      //Account create
      final response = await _supabase.auth.signUp(
        email: event.email.trim(),
        password: event.password,
        data: {'nickname': event.nickname.trim()},
        emailRedirectTo: authRedirectUrl,
      );
      if (response.session == null) {
        // Supabase requires e-mail confirmation - no session yet, so the user is not let into the app.
        emit(const AuthMessage('Account created. Confirm your e-mail address, then sign in.'));
        emit(const Unauthenticated(isRegistering: false));
        return;
      }
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(const Unauthenticated(isRegistering: true));
    }
  }

  Future<void> _onGoogleSignInPressed(GoogleSignInPressed event, Emitter<AuthState> emit) async {
    final registering = state is Unauthenticated && (state as Unauthenticated).isRegistering;
    try {
      // Opens the browser; the session arrives through the deep link and is handled by [_onSessionChanged].
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(Unauthenticated(isRegistering: registering));
    }
  }

  Future<void> _onPasswordResetRequested(PasswordResetRequested event, Emitter<AuthState> emit) async {
    final error = Validators.email(event.email);
    if (error != null) {
      emit(AuthFailure(error));
      emit(const Unauthenticated(isRegistering: false));
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(event.email.trim(), redirectTo: authRedirectUrl);
      emit(const AuthMessage('If the account exists, a password reset link has been sent to your e-mail.'));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
    }
    emit(const Unauthenticated(isRegistering: false));
  }

  Future<void> _onPasswordUpdateRequested(PasswordUpdateRequested event, Emitter<AuthState> emit) async {
    final error = Validators.password(event.newPassword);
    if (error != null) {
      emit(AuthFailure(error));
      emit(PasswordRecovery());
      return;
    }

    emit(AuthLoading());
    try {
      final response = await _supabase.auth.updateUser(UserAttributes(password: event.newPassword));
      emit(const AuthMessage('Password updated.'));
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(PasswordRecovery());
    }
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    switch (event.event) {
      case AuthChangeEvent.passwordRecovery:
        emit(PasswordRecovery());
      case AuthChangeEvent.signedIn:
        final session = event.session;
        if (session != null && state is! PasswordRecovery && state is! AuthLoading) {
          emit(Authenticated(session.user.id));
        }
      case AuthChangeEvent.signedOut:
        if (state is Authenticated) emit(const Unauthenticated(isRegistering: false));
      default:
        break;
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    emit(const Unauthenticated(isRegistering: false));
  }
}

/// User-friendly text for an auth error (Supabase errors carry a readable message).
String _messageOf(Object error) {
  if (error is AuthException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}
