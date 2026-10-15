import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../logic/auth/auth_state.dart';
import 'widgets/loading_view.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

/// Ekran logowania/rejestracji. Przejście do MainScreen robi main.dart (BlocBuilder na AuthState),
/// a błędy logowania pokazuje BlocListener w main.dart.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Unauthenticated) {
            return state.isRegistering ? const RegisterForm() : const LoginForm();
          }
          return const LoadingView();
        },
      ),
    );
  }
}
