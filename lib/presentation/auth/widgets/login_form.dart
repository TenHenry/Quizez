import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/validators.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../common/app_text_field.dart';
import 'google_sign_in_button.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final emailError = Validators.email(_emailController.text);
    final passwordError = _passwordController.text.isEmpty ? 'Enter your password' : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError == null && passwordError == null) {
      context.read<AuthBloc>().add(LoginWithEmailPressed(_emailController.text, _passwordController.text));
    }
  }

  void _forgotPassword() {
    final controller = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We will send a reset link to this e-mail address.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'email@domain.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthBloc>().add(PasswordResetRequested(controller.text));
              Navigator.pop(dialogContext);
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Quizez', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 40),
          const Text('Sign in', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 24),
          AppTextField(hint: 'email@domain.com', controller: _emailController, keyboardType: TextInputType.emailAddress, errorText: _emailError),
          AppTextField(hint: 'password', controller: _passwordController, isPassword: true, errorText: _passwordError),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: const Text('Forgot password?', style: TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _submit, child: const Text('Continue', style: TextStyle(fontSize: 16))),
          const SizedBox(height: 20),
          const GoogleSignInButton(),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.read<AuthBloc>().add(ToggleAuthMode()),
            child: const Text("Don't have an account? Sign up", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
