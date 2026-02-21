import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/dashboard_screen.dart';
import '../main.dart'; // Needed to access LandingWrapper and createSlideRoute

class VeriscanDrawer extends StatelessWidget {
  const VeriscanDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // --- HEADER ---
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    "VERISCAN",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFD4AF37),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- MENU ITEMS ---
          const SizedBox(height: 20),
          _buildMenuItem(
            context,
            icon: Icons.home_filled,
            label: "Home",
            onTap: () {
              Navigator.pop(context); // Close drawer first
              // Use the smooth slide animation
              Navigator.of(context).pushReplacement(createSlideRoute(const LandingWrapper()));
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.dashboard_customize,
            label: "Dashboard",
            onTap: () {
              Navigator.pop(context); // Close drawer first
              // Use the smooth slide animation
              Navigator.of(context).pushReplacement(createSlideRoute(const DashboardScreen()));
            },
          ),
          
          const Spacer(),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "VeriScan v1.0",
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
}