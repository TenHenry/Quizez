import 'package:flutter/material.dart';
import 'package:quizez/presentation/home/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'logic/auth/auth_bloc.dart';
import 'logic/auth/auth_event.dart';
import 'logic/auth/auth_state.dart';
import 'presentation/auth/auth_screen.dart';
import 'data/services/database_service.dart';
import 'data/services/sync_service.dart';
import 'logic/learning/learning_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vkgdqawrvaztwdchrasz.supabase.co',
    anonKey: 'sb_publishable_ql2FSmF1BVuDOu-i-zNOzA_WDCon0_o',
  );

  // The local database is opened lazily per signed-in user (see DatabaseService.db).
  final databaseService = DatabaseService();
  final syncService = SyncService(databaseService);

  runApp(MyApp(databaseService: databaseService, syncService: syncService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.databaseService, required this.syncService});

  final DatabaseService databaseService;
  final SyncService syncService;

  // Lets us show a SnackBar with an auth error regardless of which screen is in the tree.
  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: databaseService),
        RepositoryProvider.value(value: syncService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => LearningBloc(databaseService)),
          BlocProvider(create: (context) => AuthBloc()..add(AppStarted())),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthFailure) {
              _messengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            } else if (state is AuthMessage) {
              _messengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.green),
              );
            } else if (state is Authenticated) {
              syncService.requestSync(); // pull the user's data right after sign-in
            }
          },
          child: MaterialApp(
            scaffoldMessengerKey: _messengerKey,
            title: 'Quizez',
            theme: AppTheme.light,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                // Splash, forms and the loader all live inside AuthScreen so typed text survives errors.
                return state is Authenticated ? const MainScreen() : const AuthScreen();
              },
            ),
          ),
        ),
      ),
    );
  }
}
