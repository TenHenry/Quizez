import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/validators.dart';
import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../common/app_text_field.dart';

/// Shown after the user opens the password reset link from the e-mail.
class ResetPasswordForm extends StatefulWidget {
  const ResetPasswordForm({super.key});

  @override
  State<ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<ResetPasswordForm> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final passwordError = Validators.password(_passwordController.text);
    final confirmError = Validators.confirmPassword(_confirmController.text, _passwordController.text);
    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    if (passwordError == null && confirmError == null) {
      context.read<AuthBloc>().add(PasswordUpdateRequested(_passwordController.text));
    }
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
          const Text('Choose a new password', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 24),
          AppTextField(hint: 'new password', controller: _passwordController, isPassword: true, errorText: _passwordError),
          AppTextField(hint: 'confirm new password', controller: _confirmController, isPassword: true, errorText: _confirmError),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _submit, child: const Text('Save password', style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
