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
      emit(AuthFailure(e.toString()));
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
      emit(Authenticated(response.user!.id));
    } catch (e) {
      emit(AuthFailure(e.toString()));
      emit(const Unauthenticated(isRegistering: true));
    }
  }
}