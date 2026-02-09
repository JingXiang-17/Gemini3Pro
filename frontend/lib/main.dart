import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';

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
      home: const DashboardScreen(),
    );
  }
}
