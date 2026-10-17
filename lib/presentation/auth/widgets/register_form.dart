import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/validators.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../common/app_text_field.dart';
import 'google_sign_in_button.dart';

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

  String? _nicknameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _submit() {
    final nicknameError = Validators.nickname(_nicknameController.text);
    final emailError = Validators.email(_emailController.text);
    final passwordError = Validators.password(_passwordController.text);
    final confirmError = Validators.confirmPassword(_confirmPasswordController.text, _passwordController.text);

    setState(() {
      _nicknameError = nicknameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if ([nicknameError, emailError, passwordError, confirmError].every((e) => e == null)) {
      context.read<AuthBloc>().add(SignUpWithEmailPressed(_nicknameController.text, _emailController.text, _passwordController.text));
    }
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
          AppTextField(hint: 'nickname', controller: _nicknameController, errorText: _nicknameError),
          AppTextField(hint: 'email', controller: _emailController, keyboardType: TextInputType.emailAddress, errorText: _emailError),
          AppTextField(hint: 'password', controller: _passwordController, isPassword: true, errorText: _passwordError),
          AppTextField(hint: 'confirm password', controller: _confirmPasswordController, isPassword: true, errorText: _confirmError),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _submit, child: const Text('Sign up', style: TextStyle(fontSize: 16))),
          const SizedBox(height: 20),
          const GoogleSignInButton(),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<AuthBloc>().add(ToggleAuthMode()),
            child: const Text('Already have an account? Sign in', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
