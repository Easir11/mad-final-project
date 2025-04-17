import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:myapp/HomePage.dart';
import 'package:myapp/ProfileDetailsPage.dart';
import 'package:myapp/auth.dart';
import 'package:myapp/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/FollowersPage.dart';
import 'package:myapp/BlockedUsersPage.dart';
import 'package:myapp/SettingsPage.dart';
import 'package:myapp/utils/firebase_service.dart';
import 'package:myapp/utils/post_service.dart';
import 'package:myapp/utils/user_service.dart';
import 'package:myapp/utils/app_state.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize services
  final firebaseService = FirebaseService();
  final postService = PostService();
  final userService = UserService();

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        Provider<PostService>.value(value: postService),
        Provider<UserService>.value(value: userService),
        ChangeNotifierProvider(
          create: (_) => AppState(
            firebaseService: firebaseService,
            postService: postService,
            userService: userService,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Social Media App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5ACD), // Purple as seed color
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF6A5ACD),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF6A5ACD), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        cardTheme: CardTheme(
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          shadowColor: Colors.black26,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthPage(),
        '/home': (context) => const HomePage(),
        '/profile-details': (context) => const ProfileDetailsPage(),
        '/followers': (context) => const FollowersPage(),
        '/blocked-users': (context) => const BlockedUsersPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
