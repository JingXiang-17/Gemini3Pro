import 'package:flutter/material.dart';

class GlobalMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const GlobalMenuButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // SafeArea ensures it doesn't get hidden behind the phone's notch
    return SafeArea(
      child: Padding(
        // THIS is the "Global Position". Change it here, it updates everywhere.
        padding: const EdgeInsets.only(left: 16.0, top: 16.0), 
        child: Container(
          // Optional: A small semi-transparent circle background to make it visible on any image
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3), 
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFD4AF37), size: 28),
            onPressed: onTap,
            tooltip: "Open Menu",
          ),
        ),
      ),
    );
  }
}