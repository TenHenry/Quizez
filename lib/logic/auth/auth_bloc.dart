import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _supabase = Supabase.instance.client;

  AuthBloc() : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<ToggleAuthMode>(_onToggleAuthMode);
    on<LoginWithEmailPressed>(_onLoginWithEmailPressed);
    on<SignUpWithEmailPressed>(_onSignUpWithEmailPressed);
    on<LogoutRequested>(_onLogoutRequested);
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
    emit(AuthLoading());
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(const Unauthenticated(isRegistering: false));
    }
  }

  Future<void> _onSignUpWithEmailPressed(SignUpWithEmailPressed event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      //Account create
      final response = await _supabase.auth.signUp(
        email: event.email,
        password: event.password,
        data: {'nickname': event.nickname},
      );
      if (response.session == null) {
        // Supabase wymaga potwierdzenia e-mail - brak sesji, więc nie wpuszczamy do aplikacji.
        emit(const AuthFailure('Account created. Confirm your e-mail address, then sign in.'));
        emit(const Unauthenticated(isRegistering: false));
        return;
      }
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(_messageOf(e)));
      emit(const Unauthenticated(isRegistering: true));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await Supabase.instance.client.auth.signOut();
    emit(const Unauthenticated(isRegistering: false));
  }
}
/// User-friendly text for an auth error (Supabase errors carry a readable message).
String _messageOf(Object error) {
  if (error is AuthException) return error.message;
  return 'Something went wrong. Check your connection and try again.';
}
