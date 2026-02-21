import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart'; // Import this to access your LandingWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<double> _sloganFade;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      // Increased total duration to 3.6 seconds to give us room for pauses
      duration: const Duration(milliseconds: 3600), 
    );

    // 1. Logo fades in (Starts immediately, finishes at 0.6s)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.2, curve: Curves.easeIn)),
    );

    // --- 0.6 second PAUSE where Flutter does nothing ---

    // 2. Title fades in (Starts at 1.2s, finishes at 1.8s)
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.6, curve: Curves.easeIn)),
    );

    // --- 0.6 second PAUSE where Flutter does nothing ---

    // 3. Slogan fades in (Starts at 2.4s, finishes at 3.0s)
    _sloganFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0, curve: Curves.easeIn)),
    );

    _startSequence();
  }

  void _startSequence() async {
    // Play the fade-in animations sequentially
    await _controller.forward();
    
    // Wait for 1 second so the user can read the full text
    await Future.delayed(const Duration(seconds: 1));

    // Navigate to your LandingWrapper (Point B), triggering the Hero flight!
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1800), // Speed of the upward flight
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: const LandingWrapper(), // <--- THIS is the crucial fix
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // HERO 1: The Logo
            Hero(
              tag: 'veriscan_logo',
              child: FadeTransition(
                opacity: _logoFade,
                child: Container(
                  width: 120, // Big size for center screen
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2.0),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.3), blurRadius: 30)
                    ]
                  ),
                  child: const Center(
                    child: Icon(Icons.shield, color: Color(0xFFD4AF37), size: 60),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // HERO 2: The Title
            Hero(
              tag: 'veriscan_title',
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    "VERISCAN: FORENSIC TRUTH ENGINE",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 28, // Big size for center screen
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // HERO 3: The Slogan
            Hero(
              tag: 'veriscan_slogan',
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _sloganFade,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "VERIFY",
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37)),
                        ),
                        TextSpan(
                          text: ", before you trust anything.",
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w300, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}