import 'dart:io';

import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:fikir/features/onboarding/data/onboarding_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class PhotosStep extends ConsumerStatefulWidget {
  const PhotosStep({super.key});

  @override
  ConsumerState<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<PhotosStep> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _statusText;

  Future<void> _pickPhoto(int slotIndex, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        requestFullMetadata: false, // Don't preserve EXIF/GPS
      );
      if (picked == null) return;

      setState(() {
        _isProcessing = true;
        _statusText = 'Compressing photo...';
      });

      // Compress on-device before storage/upload (WebP/JPEG, max 1440 long edge, <400KB cap)
      final rawFile = File(picked.path);
      final compressedResult = await ImageCompressor.compressForUpload(rawFile);

      final current = List<String>.from(
        ref.read(onboardingStateNotifierProvider).photoPaths,
      );

      if (slotIndex < current.length) {
        current[slotIndex] = compressedResult.file.path;
      } else {
        current.add(compressedResult.file.path);
      }

      ref
          .read(onboardingStateNotifierProvider.notifier)
          .updateState((s) => s.copyWith(photoPaths: current));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = null;
        });
      }
    }
  }

  void _showImageSourceDialog(int slotIndex) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: FikirColors.primaryCoral),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(slotIndex, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: FikirColors.primaryMagenta),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(slotIndex, ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    final current = List<String>.from(
      ref.read(onboardingStateNotifierProvider).photoPaths,
    );
    if (index < current.length) {
      current.removeAt(index);
      ref
          .read(onboardingStateNotifierProvider.notifier)
          .updateState((s) => s.copyWith(photoPaths: current));
    }
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    final current = List<String>.from(
      ref.read(onboardingStateNotifierProvider).photoPaths,
    );
    if (oldIndex < current.length && newIndex < current.length) {
      final item = current.removeAt(oldIndex);
      current.insert(newIndex, item);
      ref
          .read(onboardingStateNotifierProvider.notifier)
          .updateState((s) => s.copyWith(photoPaths: current));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photoPaths = ref.watch(onboardingStateNotifierProvider).photoPaths;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.addPhotosTitle ?? 'Add your photos',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.addPhotosSubtitle ??
                'Add at least 1 photo to continue. First photo is your main profile picture. Photos are cropped 4:5.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          if (_isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _statusText ?? 'Optimizing photo...',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 6-Photo Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8, // 4:5 ratio
            ),
            itemBuilder: (context, index) {
              final hasPhoto = index < photoPaths.length;
              final isMain = index == 0 && hasPhoto;

              if (hasPhoto) {
                final filePath = photoPaths[index];
                final file = File(filePath);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    if (isMain)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: FikirColors.primaryCoral,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n?.mainPhoto ?? 'Main',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                    // Reorder controls if more than 1 photo
                    if (photoPaths.length > 1)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Row(
                          children: [
                            if (index > 0)
                              InkWell(
                                onTap: () => _reorderPhotos(index, index - 1),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 14),
                                ),
                              ),
                            if (index < photoPaths.length - 1)
                              InkWell(
                                onTap: () => _reorderPhotos(index, index + 1),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              }

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showImageSourceDialog(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FikirColors.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FikirColors.primaryCoral.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: FikirColors.primaryCoral,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
