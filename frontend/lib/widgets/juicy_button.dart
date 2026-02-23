import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 1. NEEDED FOR HAPTIC FEEDBACK

class JuicyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const JuicyButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

class _JuicyButtonState extends State<JuicyButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Shrunk down to 0.96 for a more noticeable "squish" on mobile
    final double scale = _isPressed 
        ? 0.95 
        : (_isHovered ? 1.02 : 1.0); 

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        
        onTapDown: (_) {
          // 2. THE SECRET SAUCE: A tiny physical thud from the phone's motor
          HapticFeedback.lightImpact(); 
          setState(() => _isPressed = true);
        },
        
        onTapCancel: () {
          // If the user drags their finger away, cancel the press visually
          setState(() => _isPressed = false);
        },
        
        // 3. THE FORCED ANIMATION SEQUENCE
        onTap: () async {
          // Force the button to stay shrunk for a split second even on quick taps
          setState(() => _isPressed = true);
          await Future.delayed(const Duration(milliseconds: 80));
          
          // Trigger the spring bounce back up
          setState(() => _isPressed = false);
          
          // Wait for the bounce to finish before triggering the action
          await Future.delayed(const Duration(milliseconds: 150));
          
          widget.onTap(); 
        },
        
        child: AnimatedScale(
          scale: scale,
          // Sped up to 100ms so it feels snappier and less sluggish
          duration: const Duration(milliseconds: 100), 
          curve: Curves.easeOutBack, 
          child: IgnorePointer(
            child: widget.child,
          ),
        ),
      ),
    );
  }
}