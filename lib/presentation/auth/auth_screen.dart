import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../logic/auth/auth_state.dart';
import 'widgets/loading_view.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';
import 'widgets/reset_password_form.dart';

/// Sign in / sign up / new password screen.
///
/// The form stays mounted while a request is running (the loader is drawn on top of it),
/// so typed text is not lost when an error brings the user back to the form.
/// Moving on to MainScreen is done by main.dart (BlocBuilder on AuthState),
/// auth errors and messages are shown by the BlocListener in main.dart.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _formShown = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is Unauthenticated) {
      _formShown = true;
      _registering = state.isRegistering;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            setState(() {
              _formShown = true;
              _registering = state.isRegistering;
            });
          }
        },
        builder: (context, state) {
          if (state is PasswordRecovery) return const ResetPasswordForm();

          final loading = state is AuthLoading || state is AuthInitial;
          final showRegister = state is Unauthenticated ? state.isRegistering : _registering;
          final showForm = state is Unauthenticated || _formShown;

          return Stack(
            children: [
              if (showForm) showRegister ? const RegisterForm() : const LoginForm(),
              if (loading)
                Positioned.fill(
                  child: ColoredBox(
                    color: showForm ? Colors.white70 : Colors.white,
                    child: const LoadingView(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
