import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

class PhotoCheckScreen extends StatefulWidget {
  const PhotoCheckScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onConfirm,
  });

  final String title;
  final String subtitle;
  final ValueChanged<String> onConfirm;

  @override
  State<PhotoCheckScreen> createState() => _PhotoCheckScreenState();
}

class _PhotoCheckScreenState extends State<PhotoCheckScreen> {
  final _picker = ImagePicker();
  XFile? _image;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file != null) {
        setState(() => _image = file);
      }
    } catch (_) {
      // Handle permission or hardware exceptions gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null;
    
    return Scaffold(
      body: Stack(
        children: [
          // Top ambient glow
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            child: Container(
              height: 360,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Custom Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Glowing circular image container
                        Expanded(
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Accent ambient glow behind circle
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: hasImage 
                                        ? AppColors.accent.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    boxShadow: hasImage
                                        ? [
                                            BoxShadow(
                                              color: AppColors.accent.withValues(alpha: 0.2),
                                              blurRadius: 60,
                                              spreadRadius: 10,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                                
                                // Outer highlighted border
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hasImage ? AppColors.accent : AppColors.border,
                                      width: hasImage ? 2.5 : 1.5,
                                    ),
                                    color: AppColors.surface,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: hasImage
                                        ? Image.file(
                                            File(_image!.path),
                                            key: ValueKey(_image!.path),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : Column(
                                            key: const ValueKey('placeholder'),
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.surfaceElevated,
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt_outlined,
                                                  size: 28,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'No photo captured yet',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Tap Camera or Gallery below',
                                                style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Pick Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pick(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                                label: const Text('Camera'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pick(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined, size: 20),
                                label: const Text('Gallery'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Use Button
                        ContinueButton(
                          label: 'Use Photo',
                          enabled: hasImage,
                          onPressed: hasImage
                              ? () => widget.onConfirm(_image!.path)
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
