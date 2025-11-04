import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../providers/profile_provider.dart';
import '../../providers/storage_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _profilePicture;
  File? _coverPhoto;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName;
    _bioController.text = widget.user.bio ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profilePicture = File(image.path);
      });
    }
  }

  Future<void> _pickCoverPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _coverPhoto = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      String? profilePictureUrl = widget.user.profilePictureUrl;
      String? coverPhotoUrl = widget.user.coverPhotoUrl;

      // Upload profile picture
      if (_profilePicture != null) {
        profilePictureUrl = await storageService.uploadProfilePicture(
          _profilePicture!.readAsBytesSync(),
          widget.user.id,
        );
      }

      // Upload cover photo
      if (_coverPhoto != null) {
        coverPhotoUrl = await storageService.uploadCoverPhoto(
          _coverPhoto!.readAsBytesSync(),
          widget.user.id,
        );
      }

      // Update profile
      await profileService.updateProfile(
        userId: widget.user.id,
        displayName: _displayNameController.text.trim(),
        bio:
            _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
        profilePictureUrl: profilePictureUrl,
        coverPhotoUrl: coverPhotoUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Cover photo
            Stack(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child:
                      _coverPhoto != null
                          ? Image.file(_coverPhoto!, fit: BoxFit.cover)
                          : widget.user.coverPhotoUrl != null
                          ? Image.network(
                            widget.user.coverPhotoUrl!,
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _pickCoverPhoto,
                    child: const Icon(Icons.camera_alt),
                  ),
                ),
              ],
            ),
            // Profile picture
            Transform.translate(
              offset: const Offset(0, -50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              _profilePicture != null
                                  ? FileImage(_profilePicture!)
                                  : widget.user.profilePictureUrl != null
                                  ? NetworkImage(widget.user.profilePictureUrl!)
                                  : null,
                          child:
                              _profilePicture == null &&
                                      widget.user.profilePictureUrl == null
                                  ? Text(
                                    widget.user.displayName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 40),
                                  )
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickProfilePicture,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            // Form fields
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Display name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 5,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell us about yourself',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
