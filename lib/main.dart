import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:searchly/screens/home_screen.dart';
import 'package:searchly/screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SearchlyApp());
}

class SearchlyApp extends StatelessWidget {
  const SearchlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Searchly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurpleAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0x1AFFFFFF),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _checkOnboarding(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFF121212),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            );
          }
          final completed = snapshot.data ?? false;
          return completed ? const HomeScreen() : const OnboardingScreen();
        },
      ),
    );
  }

  Future<bool> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_completed_onboarding') ?? false;
  }
}
