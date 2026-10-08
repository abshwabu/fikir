import 'dart:io';

import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() => _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  final _picker = ImagePicker();
  File? _selfieFile;
  bool _isUploading = false;
  bool _isSubmitted = false;

  Future<void> _takeSelfie() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked != null) {
        final compressed = await ImageCompressor.compressForUpload(File(picked.path));
        setState(() {
          _selfieFile = compressed.file;
        });
      }
    } catch (e) {
      debugPrint('[Verification] Camera error: $e');
    }
  }

  Future<void> _submitVerification() async {
    if (_selfieFile == null) return;
    setState(() => _isUploading = true);

    // Simulate network upload to /v1/me/photos/verify
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _isUploading = false;
      _isSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.verifyProfile ?? 'Get Verified'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _isSubmitted
              ? _buildSubmittedSuccess(context, l10n)
              : _buildVerificationPrompt(context, l10n),
        ),
      ),
    );
  }

  Widget _buildVerificationPrompt(BuildContext context, AppLocalizations? l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        // Shield badge icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n?.verifyProfile ?? 'Get Verified with a Selfie',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n?.verifySubtitle ?? 'Take a quick selfie to get the blue badge and show everyone you are real.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Pose instruction box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Row(
            children: [
              Text('✌️', style: TextStyle(fontSize: 36)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match This Pose',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hold up a peace sign with your fingers and face the camera directly.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Photo Preview or Camera Placeholder
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _selfieFile != null
                ? Image.file(_selfieFile!, fit: BoxFit.cover, width: double.infinity)
                : ColoredBox(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Your selfie preview will appear here',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        if (_selfieFile == null)
          GradientButton(
            text: l10n?.takeSelfie ?? 'Take Selfie',
            onPressed: _takeSelfie,
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _takeSelfie,
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(
                  text: 'Submit Verification',
                  isLoading: _isUploading,
                  onPressed: _submitVerification,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSubmittedSuccess(BuildContext context, AppLocalizations? l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n?.pendingVerification ?? 'Verification Submitted',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n?.selfieSubmitted ??
              'Selfie submitted for verification. We will review it shortly.',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        GradientButton(
          text: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
