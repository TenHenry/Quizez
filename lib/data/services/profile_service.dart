import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile of the signed-in user (nickname, e-mail). The nickname is unique across all users.
class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get _user => _client.auth.currentUser;

  String get email => _user?.email ?? '';

  /// Nickname from sign-up metadata; falls back to the Google display name or the e-mail prefix.
  String get nickname {
    final meta = _user?.userMetadata ?? {};
    final value = meta['nickname'] ?? meta['full_name'] ?? meta['name'];
    if (value is String && value.trim().isNotEmpty) return value;
    return email.split('@').first;
  }

  /// Checks whether [nick] is free. If the check cannot be done (offline, function not deployed)
  /// it returns true - the unique index in the database is the final guard.
  Future<bool> isNicknameAvailable(String nick) async {
    try {
      final result = await _client.rpc('nickname_available', params: {'nick': nick.trim()});
      return result != false;
    } catch (_) {
      return true;
    }
  }

  /// Returns false when the nickname is already taken.
  Future<bool> updateNickname(String nick) async {
    final user = _user;
    if (user == null) return false;
    final value = nick.trim();

    try {
      await _client.from('profiles').update({'nickname': value}).eq('id', user.id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') return false; // unique violation
      rethrow;
    }
    await _client.auth.updateUser(UserAttributes(data: {'nickname': value}));
    return true;
  }
}
