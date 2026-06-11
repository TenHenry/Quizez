import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic/auth/auth_bloc.dart';
import 'logic/auth/auth_event.dart';
import 'presentation/auth/auth_screen.dart';
import 'data/services/database_service.dart';
import 'logic/learning/learning_bloc.dart';
import 'logic/learning/learning_event.dart';
import 'presentation/learning/flashcards_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vkgdqawrvaztwdchrasz.supabase.co',
    anonKey: 'sb_publishable_ql2FSmF1BVuDOu-i-zNOzA_WDCon0_o',
  );

  final databaseService = DatabaseService();
  await databaseService.db;

  await databaseService.addDummyFlashcards();

  runApp(MyApp(databaseService: databaseService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key,required this.databaseService});

  final DatabaseService databaseService;


  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => LearningBloc(databaseService)..add(LoadFlashcardsForToday()),
        ),
        BlocProvider(
        create: (context) => AuthBloc()..add(AppStarted())
        ),
      ],
      child: MaterialApp(
        title: 'Quizez',
        theme: ThemeData.light(),
        home: const AuthScreen(),
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