import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

void openFileImpl(BuildContext context, PlatformFile file) {
  // Mobile cannot open raw memory bytes as a PDF directly without a plugin.
  // We show a safe fallback note instead of crashing.
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text("Forensic Note", style: GoogleFonts.outfit(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
      content: Text(
        "File: ${file.name}\n\nThis is an analyzed attachment. Native mobile PDF viewing requires additional plugins. Please view this specific file on the Web Dashboard.", 
        style: GoogleFonts.outfit(color: Colors.white70)
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("OK", style: GoogleFonts.outfit(color: const Color(0xFFD4AF37))),
        ),
      ],
    ),
  );
}