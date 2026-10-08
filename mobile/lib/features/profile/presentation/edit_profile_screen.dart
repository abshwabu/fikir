import 'dart:io';

import 'package:fikir/core/constants/ethiopian_data.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/fikir_card.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:fikir/features/profile/data/profile_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _jobController;
  late TextEditingController _educationController;
  late TextEditingController _heightController;

  String? _selectedReligion;
  String? _selectedLookingFor = 'Marriage (ጋብቻ)';
  bool _familyOriented = true;
  bool _diasporaMode = false;
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedInterests = {};
  final List<String> _photos = [];
  final Set<String> _deletedPhotoIds = {};
  List<UserProfilePhoto> _initialPhotos = [];

  bool _isLoading = false;
  bool _isInitialized = false;

  final List<String> _availableReligions = EthiopianData.religions;
  final List<String> _availableLanguages = EthiopianData.languages;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _jobController = TextEditingController();
    _educationController = TextEditingController();
    _heightController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _initFields(UserProfile? profile) {
    if (_isInitialized || profile == null) return;
    _isInitialized = true;
    _nameController.text = profile.name;
    _bioController.text = profile.bio ?? '';
    _jobController.text = profile.jobTitle ?? '';
    _educationController.text = profile.education ?? '';
    _heightController.text = profile.heightCm != null ? profile.heightCm.toString() : '';

    if (profile.religion != null && profile.religion!.isNotEmpty) {
      if (_availableReligions.contains(profile.religion)) {
        _selectedReligion = profile.religion;
      } else {
        final match = _availableReligions.cast<String?>().firstWhere(
          (r) => r!.toLowerCase().contains(profile.religion!.toLowerCase()) || profile.religion!.toLowerCase().contains(r.toLowerCase()),
          orElse: () => null,
        );
        _selectedReligion = match;
      }
    }

    _selectedLanguages.clear();
    for (final lang in profile.languages) {
      final match = _availableLanguages.cast<String?>().firstWhere(
        (avail) => avail!.toLowerCase().contains(lang.toLowerCase()) || lang.toLowerCase().contains(avail.toLowerCase()),
        orElse: () => null,
      );
      if (match != null) {
        _selectedLanguages.add(match);
      } else {
        _selectedLanguages.add(lang);
      }
    }

    _selectedInterests.clear();
    for (final interest in profile.interests) {
      final match = EthiopianData.interests.cast<String?>().firstWhere(
        (avail) => avail!.toLowerCase().contains(interest.toLowerCase()) || interest.toLowerCase().contains(avail.toLowerCase()),
        orElse: () => null,
      );
      if (match != null) {
        _selectedInterests.add(match);
      } else {
        _selectedInterests.add(interest);
      }
    }

    _photos.clear();
    _initialPhotos = List.from(profile.photos);
    for (final p in profile.photos) {
      if (p.url.isNotEmpty) {
        _photos.add(p.url);
      }
    }
  }

  int _calculateCompleteness() {
    var score = 0;
    if (_photos.isNotEmpty) score += 30;
    if (_nameController.text.trim().isNotEmpty) score += 10;
    if (_bioController.text.trim().isNotEmpty) score += 20;
    if (_jobController.text.trim().isNotEmpty) score += 10;
    if (_educationController.text.trim().isNotEmpty) score += 10;
    if (_selectedReligion != null) score += 5;
    if (_selectedLanguages.isNotEmpty) score += 5;
    if (_selectedInterests.length >= 3) score += 10;
    return score.clamp(0, 100);
  }

  Future<void> _pickPhoto(int slotIndex) async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final compressed = await ImageCompressor.compressForUpload(File(picked.path));
        setState(() {
          if (slotIndex < _photos.length) {
            _photos[slotIndex] = compressed.file.path;
          } else {
            _photos.add(compressed.file.path);
          }
        });
      }
    } catch (e) {
      debugPrint('[EditProfile] Pick photo error: $e');
    }
  }

  void _deletePhoto(int index) {
    if (_photos.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least 1 photo.')),
      );
      return;
    }

    final removed = _photos.removeAt(index);
    final existing = _initialPhotos.cast<UserProfilePhoto?>().firstWhere(
      (p) => p!.url == removed,
      orElse: () => null,
    );
    if (existing != null && existing.id.isNotEmpty) {
      _deletedPhotoIds.add(existing.id);
    }

    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = ref.read(profileRepositoryProvider);

    // 1. Delete removed photos from backend
    for (final photoId in _deletedPhotoIds) {
      try {
        await repo.deletePhoto(photoId);
      } catch (e) {
        debugPrint('[EditProfile] Failed to delete photo $photoId: $e');
      }
    }
    _deletedPhotoIds.clear();

    // 2. Upload any local file photos
    for (final photoPath in _photos) {
      final file = File(photoPath);
      if (file.existsSync()) {
        try {
          await repo.uploadPhoto(file);
        } catch (e) {
          debugPrint('[EditProfile] Failed to upload photo $photoPath: $e');
        }
      }
    }

    // 3. Update profile fields
    final height = int.tryParse(_heightController.text.trim());
    final result = await repo.updateProfile(
      displayName: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      jobTitle: _jobController.text.trim(),
      education: _educationController.text.trim(),
      heightCm: height,
      religion: _selectedReligion,
      languages: _selectedLanguages.toList(),
      interests: _selectedInterests.toList(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop();
        },
        failure: (err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${err.message}')),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(myUserProfileProvider);

    profileAsync.whenData(_initFields);
    final completeness = _calculateCompleteness();
    final religionValue = _availableReligions.contains(_selectedReligion) ? _selectedReligion : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Completeness Progress Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FikirColors.primaryCoral.withAlpha(25),
                      FikirColors.primaryMagenta.withAlpha(25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n?.profileCompleteness ?? 'Profile Completeness',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '$completeness%',
                          style: const TextStyle(
                            color: FikirColors.primaryCoral,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: completeness / 100,
                        minHeight: 8,
                        backgroundColor: Colors.black12,
                        valueColor: const AlwaysStoppedAnimation<Color>(FikirColors.primaryCoral),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Photos Grid (6 Slots)
              Text(
                'Photos (${_photos.length}/6)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final hasPhoto = index < _photos.length;
                  return _buildPhotoSlot(index, hasPhoto);
                },
              ),
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Bio Field
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n?.bio ?? 'Bio',
                  hintText: l10n?.bioPlaceholder ?? 'Write something sweet about yourself...',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Job Title & Education
              TextFormField(
                controller: _jobController,
                decoration: InputDecoration(
                  labelText: l10n?.jobTitle ?? 'Job Title',
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _educationController,
                decoration: const InputDecoration(
                  labelText: 'Education / University',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Height
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  prefixIcon: Icon(Icons.height_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Looking For (Relationship Goals)
              const Text(
                'Looking For (ግንኙነት)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedLookingFor,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                items: const [
                  DropdownMenuItem(value: 'Marriage (ጋብቻ)', child: Text('💍 Marriage (ጋብቻ)')),
                  DropdownMenuItem(value: 'Serious Relationship (ዘላቂ ግንኙነት)', child: Text('❤️ Serious Relationship (ዘላቂ ግንኙነት)')),
                  DropdownMenuItem(value: 'Casual / Friends (ጓደኝነት)', child: Text('☕ Casual / Friends (ጓደኝነት)')),
                  DropdownMenuItem(value: 'Still Figuring Out (እያሰብኩበት ነው)', child: Text('🤔 Still Figuring Out (እያሰብኩበት ነው)')),
                ],
                onChanged: (val) => setState(() => _selectedLookingFor = val),
              ),
              const SizedBox(height: 16),

              // Cultural Badges: Family-Oriented & Diaspora Mode
              FikirCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.people_alt_outlined, color: FikirColors.primaryCoral),
                      title: const Text('Family-Oriented (ቤተሰብ ወዳድ)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Display family-focused badge on profile', style: TextStyle(fontSize: 12)),
                      value: _familyOriented,
                      activeThumbColor: FikirColors.primaryCoral,
                      onChanged: (val) => setState(() => _familyOriented = val),
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.flight_takeoff_rounded, color: Colors.blueAccent),
                      title: const Text('Ethiopian Diaspora Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Connect with Ethiopians globally', style: TextStyle(fontSize: 12)),
                      value: _diasporaMode,
                      activeThumbColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _diasporaMode = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Religion Selector
              Text(
                l10n?.religion ?? 'Religion',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: religionValue,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                hint: const Text('Select Religion'),
                items: _availableReligions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => _selectedReligion = val),
              ),
              const SizedBox(height: 24),

              // Languages Spoken Chips
              const Text(
                'Languages Spoken',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableLanguages.map((lang) {
                  final isSelected = _selectedLanguages.contains(lang);
                  return FilterChip(
                    label: Text(lang),
                    selected: isSelected,
                    selectedColor: FikirColors.primaryCoral.withAlpha(51),
                    checkmarkColor: FikirColors.primaryCoral,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLanguages.add(lang);
                        } else {
                          _selectedLanguages.remove(lang);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Interests Chips
              Text(
                l10n?.selectInterestsTitle ?? 'Interests',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EthiopianData.interests.take(15).map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    selectedColor: FikirColors.primaryMagenta.withAlpha(51),
                    checkmarkColor: FikirColors.primaryMagenta,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save Button
              GradientButton(
                text: 'Save Changes',
                isLoading: _isLoading,
                onPressed: _saveProfile,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSlot(int index, bool hasPhoto) {
    if (hasPhoto) {
      final photo = _photos[index];
      final isLocal = File(photo).existsSync();

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isLocal
                ? Image.file(File(photo), fit: BoxFit.cover)
                : Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _deletePhoto(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
          if (index == 0)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FikirColors.primaryCoral,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Main',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _pickPhoto(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Icon(Icons.add_photo_alternate_outlined, color: FikirColors.primaryCoral, size: 28),
        ),
      ),
    );
  }
}
