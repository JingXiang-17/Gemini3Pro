import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:google_fonts/google_fonts.dart';

enum InputMode { text, link, image }

class InputSection extends StatefulWidget {
  final Function(String? text, String? url, PlatformFile? image) onAnalyze;
  final bool isLoading;

  const InputSection({
    super.key,
    required this.onAnalyze,
    required this.isLoading,
  });

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  PlatformFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _selectedImage = result.files.first;
      });
    }
  }

  void _submit() {
    switch (_tabController.index) {
      case 0: // Text
        widget.onAnalyze(_textController.text, null, null);
        break;
      case 1: // Link
        widget.onAnalyze(null, _linkController.text, null);
        break;
      case 2: // Image
        widget.onAnalyze(null, null, _selectedImage);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Text"),
              Tab(text: "Link Analysis"),
              Tab(text: "Image"),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Input Area
        SizedBox(
          height: 180,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Text Input
              TextField(
                controller: _textController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Paste suspect text here...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              // Link Input
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _linkController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.link, color: Color(0xFFD4AF37)),
                      hintText: "Paste article URL...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),

              // Image Input
              GestureDetector(
                onTap: _pickImage,
                child: DottedBorder(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  strokeWidth: 2,
                  dashPattern: const [6, 3],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_selectedImage != null) ...[
                          const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50), size: 40),
                          const SizedBox(height: 8),
                          Text(
                            _selectedImage!.name,
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                          TextButton(
                              onPressed: _pickImage,
                              child: const Text("Change",
                                  style: TextStyle(color: Color(0xFFD4AF37))))
                        ] else ...[
                          const Icon(Icons.cloud_upload_outlined,
                              color: Colors.white54, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            "Click to upload image forensics",
                            style: GoogleFonts.outfit(color: Colors.white54),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Analyze Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2),
                  )
                : Text(
                    "ANALYZE NOW",
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
