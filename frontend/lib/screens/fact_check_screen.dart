import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';

class FactCheckScreen extends StatefulWidget {
  const FactCheckScreen({super.key});

  @override
  State<FactCheckScreen> createState() => _FactCheckScreenState();
}

class _FactCheckScreenState extends State<FactCheckScreen> {
  final TextEditingController _controller = TextEditingController();
  final FactCheckService _service = FactCheckService();
  FactCheckResult? _result;
  bool _isLoading = false;

  Future<void> _handleVerify() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final result = await _service.analyzeNews(_controller.text);
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'VeriScan AI',
          style: GoogleFonts.outfit(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify the truth with Gemini AI',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste news text or claim here...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4AF37), width: 1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      'Verify Claim',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final bool isReal = _result!.isValid;
    final Color accentColor =
        isReal ? const Color(0xFFD4AF37) : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: isReal
            ? [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isReal ? 'VERIFIED REAL' : 'POTENTIAL MISINFORMATION',
                style: GoogleFonts.outfit(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(_result!.confidenceScore * 100).toInt()}% Confidence',
                  style: TextStyle(color: accentColor, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Analysis',
            style: GoogleFonts.outfit(
              color: Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _result!.analysis,
            style:
                const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Key Findings',
            style: GoogleFonts.outfit(
              color: Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._result!.keyFindings.map((finding) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: accentColor)),
                    Expanded(
                      child: Text(
                        finding,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
