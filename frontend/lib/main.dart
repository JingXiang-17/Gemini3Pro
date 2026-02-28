import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/dashboard_landing_view.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const VeriScanApp());
}

class VeriScanApp extends StatelessWidget {
  const VeriScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeriScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          primary: const Color(0xFFD4AF37),
          onPrimary: Colors.black,
          surface: const Color(0xFF1E1E1E),
          onSurface: const Color(0xFFE0E0E0),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme.copyWith(
                bodyLarge: const TextStyle(color: Color(0xFFE0E0E0)),
                bodyMedium: const TextStyle(color: Color(0xFFB0B0B0)),
              ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: Colors.black,
            textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class LandingWrapper extends StatelessWidget {
  const LandingWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardLandingView(
      // Use helper for sliding animation
      onStartAnalysis: () {
        Navigator.of(context)
            .pushReplacement(createSlideRoute(const DashboardScreen()));
      },
    );
  }
}

// Helper for smooth "Gemini-style" sliding navigation
Route createSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.1, 0.0); // Slight slide from right
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic; // Smooth ease

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      // Combine Slide with Fade for that premium feel
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 200), // Ultra-fast
  );
}
