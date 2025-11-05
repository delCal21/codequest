import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:codequest/config/firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:codequest/features/challenges/data/challenge_repository.dart';
import 'package:codequest/features/challenges/presentation/bloc/challenge_bloc.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:codequest/config/theme.dart';
import 'package:codequest/config/routes.dart';

Future<void> initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');

      // Set persistence only on web
      if (kIsWeb) {
        await Future.delayed(
            const Duration(seconds: 1)); // Wait for web SDK to initialize
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        print('Firebase web persistence set to LOCAL');

        // Verify auth state
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('Current user found: ${user.email}');
        } else {
          print('No current user');
        }
      }
    } else {
      // If Firebase is already initialized, use the existing app
      Firebase.app();
      print('Firebase already initialized, using existing app');
    }
  } catch (e) {
    if (e is FirebaseException && e.code == 'duplicate-app') {
      // Ignore duplicate app error
      print('Firebase already initialized');
    } else {
      print('Error initializing Firebase: ${e.toString()}');
      // Rethrow the error to handle it in the app
      rethrow;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await initializeFirebase();
    
    // Verify Firebase Storage is accessible
    try {
      final storage = FirebaseStorage.instance;
      print('Firebase Storage initialized successfully');
      
      // Test storage access (this will fail if not authenticated or rules are wrong)
      if (kIsWeb) {
        // On web, we need to wait for auth to be ready
        await Future.delayed(const Duration(seconds: 2));
      }
      
    } catch (storageError) {
      print('Firebase Storage initialization warning: $storageError');
      // Don't fail the app, just log the warning
    }
    
    runApp(const MyApp());
  } catch (e) {
    print('Fatal error during initialization: ${e.toString()}');
    // You might want to show an error screen here
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: ${e.toString()}'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepositoryImpl>(
          create: (context) => AuthRepositoryImpl(),
        ),
        RepositoryProvider<ChallengeRepository>(
          create: (context) => ChallengeRepository(FirebaseFirestore.instance),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepositoryImpl>()),
          ),
          BlocProvider<ChallengeBloc>(
            create: (context) => ChallengeBloc(
              context.read<ChallengeRepository>(),
              FirebaseStorage.instance,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'CodeQuest',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: '/',
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
