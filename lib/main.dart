import 'package:flutter/material.dart';
import 'package:quizez/presentation/home/main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic/auth/auth_bloc.dart';
import 'logic/auth/auth_event.dart';
import 'logic/auth/auth_state.dart';
import 'presentation/auth/auth_screen.dart';
import 'data/services/database_service.dart';
import 'logic/learning/learning_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vkgdqawrvaztwdchrasz.supabase.co',
    anonKey: 'sb_publishable_ql2FSmF1BVuDOu-i-zNOzA_WDCon0_o',
  );

  final databaseService = DatabaseService();
  await databaseService.db;


  runApp(MyApp(databaseService: databaseService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key,required this.databaseService});

  final DatabaseService databaseService;


  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: databaseService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => LearningBloc(databaseService),
          ),
          BlocProvider(
          create: (context) => AuthBloc()..add(AppStarted())
          ),
        ],
        child: MaterialApp(
          title: 'Quizez',
          theme: ThemeData.light(),
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is Authenticated) {
                return const MainScreen();
              } else if (state is Unauthenticated || state is AuthFailure) {
                return const AuthScreen();
              }
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(child: CircularProgressIndicator(color: Colors.black)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _future = Supabase.instance.client
      .from('todos')
      .select();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = snapshot.data!;
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: ((context, index) {
              final todo = todos[index];
              return ListTile(
                title: Text(todo['Quizez']),
              );
            }),
          );
        },
      ),
    );
  }
}