import 'dart:io';

import 'package:fikir/core/constants/ethiopian_data.dart';
import 'package:fikir/core/database/app_database.dart';
import 'package:fikir/core/design/colors.dart';
import 'package:fikir/core/design/widgets/gradient_button.dart';
import 'package:fikir/core/utils/image_compressor.dart';
import 'package:fikir/features/profile/data/profile_repository.dart';
import 'package:fikir/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final myProfileStreamProvider = StreamProvider<CachedProfile?>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchMyProfile('me');
});

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
  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedInterests = {};
  final List<String> _photos = [];

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

  void _initFields(CachedProfile? profile) {
    if (_isInitialized || profile == null) return;
    _isInitialized = true;
    _nameController.text = profile.name;
    _bioController.text = profile.bio ?? '';
    _jobController.text = 'Software Engineer';
    _educationController.text = 'Addis Ababa University';
    _heightController.text = '175';
    _selectedReligion = 'Ethiopian Orthodox (ኦርቶዶክስ)';
    _selectedLanguages.addAll(['አማርኛ (Amharic)', 'English']);
    _selectedInterests.addAll(['Coffee (ቡና)', 'Music', 'Hiking']);

    // Seed default photo if empty
    if (_photos.isEmpty) {
      _photos.add('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400');
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
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
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
    final profileAsync = ref.watch(myProfileStreamProvider);

    profileAsync.whenData(_initFields);
    final completeness = _calculateCompleteness();

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

              // Religion Selector
              Text(
                l10n?.religion ?? 'Religion',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedReligion,
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
                : Image.network(photo, fit: BoxFit.cover),
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
