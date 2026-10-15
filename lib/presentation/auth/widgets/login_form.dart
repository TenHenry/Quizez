import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../common/app_text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Quizez', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 40),
          const Text('Sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 24),
          AppTextField(hint: 'email@domain.com', controller: _emailController, keyboardType: TextInputType.emailAddress),
          AppTextField(hint: 'password', controller: _passwordController, isPassword: true),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.read<AuthBloc>().add(LoginWithEmailPressed(_emailController.text, _passwordController.text)),
            child: const Text('Continue', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.read<AuthBloc>().add(ToggleAuthMode()),
            child: const Text("Don't have an account? Sign up", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
