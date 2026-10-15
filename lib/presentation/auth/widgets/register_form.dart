import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../common/app_text_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Quizez', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 30),
          const Text('Sign up', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 24),
          AppTextField(hint: 'nickname', controller: _nicknameController),
          AppTextField(hint: 'email', controller: _emailController, keyboardType: TextInputType.emailAddress),
          AppTextField(hint: 'password', controller: _passwordController, isPassword: true),
          AppTextField(hint: 'confirm password', controller: _confirmPasswordController, isPassword: true),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (_passwordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red));
                return;
              }
              context.read<AuthBloc>().add(SignUpWithEmailPressed(_nicknameController.text, _emailController.text, _passwordController.text));
            },
            child: const Text('Sign up', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.read<AuthBloc>().add(ToggleAuthMode()),
            child: const Text('Already have an account? Sign in', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
