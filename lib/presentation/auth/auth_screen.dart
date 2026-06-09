import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../logic/auth/auth_state.dart';
import 'widgets/loading_view.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
          if (state is Authenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zalogowano!'), backgroundColor: Colors.green),
            );
          }
        },
        builder: (context, state) {
          // Widget swap
          if (state is AuthLoading || state is AuthInitial) {
            return const LoadingView();
          } else if (state is Unauthenticated) {
            return state.isRegistering ? const RegisterForm() : const LoginForm();
          }
          return const Center(child: Text('Jesteś zalogowany!'));
        },
      ),
    );
  }
}