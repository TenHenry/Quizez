import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/validators.dart';
import '../../data/services/profile_service.dart';
import '../../logic/auth/auth_bloc.dart';
import '../../logic/auth/auth_event.dart';

/// Profile (avatar, nickname, e-mail) and sign out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profile = ProfileService();

  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _profile.nickname);
    String? error;

    final newNickname = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change nickname', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: 'nickname', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final validation = Validators.nickname(controller.text);
                if (validation != null) {
                  setDialogState(() => error = validation);
                } else {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (newNickname == null || newNickname == _profile.nickname || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await _profile.updateNickname(newNickname);
      if (!mounted) return;
      if (saved) {
        setState(() {});
      }
      messenger.showSnackBar(SnackBar(
        content: Text(saved ? 'Nickname updated.' : 'This nickname is already taken.'),
        backgroundColor: saved ? Colors.green : Colors.red,
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not update the nickname. Check your connection.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _profile.nickname;
    final initial = nickname.isEmpty ? '?' : nickname[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.black,
              child: Text(initial, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Center(child: Text(_profile.email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change nickname'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editNickname,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
