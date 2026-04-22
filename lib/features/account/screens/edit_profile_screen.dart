import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/services/avatar_upload_service.dart';
import '../../../shared/models/creator_model.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/styles/app_brand_styles.dart';
import '../../../shared/widgets/brand_app_chrome.dart';
import '../../auth/providers/auth_provider.dart';
import '../../creator/services/creator_gallery_service.dart';
import '../../home/providers/home_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); // For creators
  final TextEditingController _aboutController = TextEditingController(); // For creators
  final TextEditingController _ageController = TextEditingController(); // For creators
  final ApiClient _apiClient = ApiClient();
  final CreatorGalleryService _creatorGalleryService = CreatorGalleryService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _selectedAvatar;
  final Set<String> _selectedCategories = {};
  late PageController _pageController;

  final List<String> _categories = [
    'Trauma',
    'Health',
    'Breakup',
    'Low confidence',
    'Loneliness',
    'Stress',
    'Work',
    'Family',
    'Relationship',
  ];

  /// Whether the user picked a *new* local avatar (different from what was saved).
  bool _avatarChanged = false;

  /// Gallery image bytes (if user picked a photo from gallery).
  Uint8List? _galleryImageBytes;

  /// Gallery image file name.
  String? _galleryImageName;

  /// Whether the user is using a gallery image instead of a preset avatar.
  bool _usingGalleryImage = false;
  bool _isGalleryLoading = false;
  String? _galleryActionImageId;
  List<CreatorGalleryImage> _creatorGalleryImages = const [];
  Uint8List? _pendingGalleryPreviewBytes;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final availableAvatars = _getAvailableAvatars();

    if (user != null) {
      _usernameController.text = user.username ?? user.id.substring(0, 9);
      if (user.categories != null) {
        _selectedCategories.addAll(user.categories!);
      }
      
      // Initialize creator-specific fields if user is a creator
      final isCreator = user.role == 'creator' || user.role == 'admin';
      if (isCreator) {
        // Get creator data from auth state (it includes creator fields when user is creator)
        _nameController.text = user.name ?? '';
        _aboutController.text = user.about ?? '';
        if (user.age != null) {
          _ageController.text = user.age.toString();
        }
        _loadCreatorGalleryImages();
      }

      // If the stored avatar is a URL, distinguish preset URL vs gallery URL.
      final storedAvatar = user.avatar;
      if (storedAvatar != null &&
          (storedAvatar.startsWith('http://') ||
              storedAvatar.startsWith('https://'))) {
        if (AvatarUploadService.isPresetAvatarUrl(storedAvatar)) {
          _usingGalleryImage = false;
          final extractedName =
              AvatarUploadService.extractPresetAvatarName(storedAvatar);
          if (extractedName != null && availableAvatars.contains(extractedName)) {
            _selectedAvatar = extractedName;
          } else {
            _selectedAvatar =
                availableAvatars.isNotEmpty ? availableAvatars[0] : null;
          }
        } else {
          _usingGalleryImage = true;
          _selectedAvatar =
              availableAvatars.isNotEmpty ? availableAvatars[0] : null;
        }
      } else if (storedAvatar != null &&
          availableAvatars.contains(storedAvatar)) {
        _selectedAvatar = storedAvatar;
      } else {
        _selectedAvatar =
            availableAvatars.isNotEmpty ? availableAvatars[0] : null;
      }
    }

    // Initialize PageController with selected avatar index
    final initialIndex =
        _selectedAvatar != null && availableAvatars.contains(_selectedAvatar!)
            ? availableAvatars.indexOf(_selectedAvatar!)
            : 0;
    _pageController = PageController(
      viewportFraction: 0.6,
      initialPage: initialIndex,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _aboutController.dispose();
    _ageController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getAvailableAvatars() {
    final user = ref.read(authProvider).user;
    final gender = user?.gender ?? 'male';
    return AvatarUploadService.getAvailablePresetAvatarNames(gender);
  }

  // ── Gallery Permission & Picker ────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return; // User cancelled

      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;

      debugPrint('📸 [GALLERY] Picked image: $fileName (${bytes.length} bytes)');

      setState(() {
        _galleryImageBytes = bytes;
        _galleryImageName = fileName;
        _usingGalleryImage = true;
        _avatarChanged = true;
      });
    } catch (e) {
      debugPrint('❌ [GALLERY] Error picking image: $e');
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t pick image. Please try again.',
          ),
        );
      }
    }
  }

  /// Request gallery / photo library permission.
  ///
  /// On Android 13+ this is [Permission.photos].
  /// On older Android it's [Permission.storage].
  Future<bool> _requestGalleryPermission() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      // Android 13+ uses READ_MEDIA_IMAGES; older uses READ_EXTERNAL_STORAGE
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      // Fallback for older Android
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    } else {
      // iOS
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
      return false;
    }

    // image_picker on Android can often work even without explicit permission
    // granted via permission_handler (it uses the system's activity-result API).
    // So we return true and let image_picker handle its own fallback.
    return true;
  }

  void _showPermissionDeniedDialog() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Permission Required',
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          'Photo access is needed to pick a profile picture from your gallery. '
          'Please enable it in your device settings.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCreatorGalleryImages() async {
    setState(() => _isGalleryLoading = true);
    try {
      final images = await _creatorGalleryService.getMyGalleryImages();
      if (!mounted) return;
      setState(() {
        _creatorGalleryImages = images;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context,
        UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t load creator pictures. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGalleryLoading = false);
      }
    }
  }

  String _contentTypeForFileName(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/jpeg';
  }

  Future<void> _addCreatorGalleryImage() async {
    if (_isGalleryLoading || _creatorGalleryImages.length >= CreatorGalleryService.maxImages) {
      return;
    }

    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingGalleryPreviewBytes = bytes;
        _isGalleryLoading = true;
      });
      final images = await _creatorGalleryService.uploadGalleryImage(
        imageBytes: bytes,
        fileName: pickedFile.name,
        contentType: _contentTypeForFileName(pickedFile.name),
      );
      if (!mounted) return;
      setState(() {
        _creatorGalleryImages = images;
        _pendingGalleryPreviewBytes = null;
      });
      ref.read(creatorsProvider.notifier).refreshFeed();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context,
        UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t upload image. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGalleryLoading = false;
          _pendingGalleryPreviewBytes = null;
        });
      }
    }
  }

  Future<void> _removeCreatorGalleryImage(String imageId) async {
    if (_galleryActionImageId != null) return;
    setState(() => _galleryActionImageId = imageId);
    try {
      final images = await _creatorGalleryService.deleteGalleryImage(imageId);
      if (!mounted) return;
      setState(() {
        _creatorGalleryImages = images;
      });
      ref.read(creatorsProvider.notifier).refreshFeed();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context,
        UserMessageMapper.userMessageFor(
          e,
          fallback: 'Couldn\'t delete image. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _galleryActionImageId = null);
      }
    }
  }

  // ── Save Profile ──────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      AppToast.showInfo(context, 'Please enter a username');
      return;
    }

    if (username.length < 4 || username.length > 10) {
      AppToast.showInfo(context, 'Username must be 4-10 characters');
      return;
    }

    if (_selectedCategories.length > 4) {
      AppToast.showInfo(context, 'Please select maximum 4 categories');
      return;
    }

    final currentUser = ref.read(authProvider).user;
    final isCreator = currentUser?.role == 'creator' || currentUser?.role == 'admin';
    if (isCreator && _creatorGalleryImages.isEmpty) {
      AppToast.showInfo(context, 'Please upload at least 1 creator picture');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [EDIT PROFILE] Saving profile...');
      debugPrint('   Username: $username');
      debugPrint('   Avatar: $_selectedAvatar');
      debugPrint('   Avatar changed: $_avatarChanged');
      debugPrint('   Using gallery: $_usingGalleryImage');
      debugPrint('   Categories: ${_selectedCategories.toList()}');

      final user = ref.read(authProvider).user;
      final isCreator = user?.role == 'creator' || user?.role == 'admin';
      final authState = ref.read(authProvider);

      String? avatarValue;
      String? creatorPhotoValue;

      // Handle avatar/photo upload for both users and creators
      if (_avatarChanged) {
        final firebaseUid = authState.firebaseUser?.uid;
        if (firebaseUid != null) {
          if (_usingGalleryImage && _galleryImageBytes != null) {
            // ── Upload gallery image ─────────────────────────────
            debugPrint(
                '🖼️  [EDIT PROFILE] Uploading gallery image to Firebase Storage...');
            final uploadedUrl = await AvatarUploadService.uploadGalleryImage(
              firebaseUid: firebaseUid,
              imageBytes: _galleryImageBytes!,
              fileName: _galleryImageName ?? 'gallery.png',
            );
            debugPrint('✅ [EDIT PROFILE] Gallery avatar uploaded: $uploadedUrl');
            if (isCreator) {
              creatorPhotoValue = uploadedUrl;
            } else {
              avatarValue = uploadedUrl;
            }
          } else if (_selectedAvatar != null) {
            // ── Resolve preset avatar URL from Firebase Storage ──
            debugPrint(
                '🖼️  [EDIT PROFILE] Resolving preset avatar URL...');
            final presetUrl = await AvatarUploadService.getPresetAvatarUrl(
              avatarName: _selectedAvatar!,
              gender: user?.gender ?? 'male',
            );
            debugPrint('✅ [EDIT PROFILE] Preset avatar resolved: $presetUrl');
            if (isCreator) {
              creatorPhotoValue = presetUrl;
            } else {
              avatarValue = presetUrl;
            }
          }
        }
      }

      // Save user profile (username, avatar, categories)
      final userResponse = await _apiClient.put(
        '/user/profile',
        data: {
          'username': username,
          if (!isCreator && avatarValue != null) 'avatar': avatarValue,
          'categories': _selectedCategories.toList(),
        },
      );

      if (userResponse.statusCode != 200) {
        throw Exception('Failed to save user profile: ${userResponse.statusCode}');
      }

      // If creator, also update creator profile (name, about, age, categories)
      if (isCreator) {
        final name = _nameController.text.trim();
        final about = _aboutController.text.trim();
        final ageText = _ageController.text.trim();
        
        // Validate creator fields
        if (name.isEmpty || name.length < 2 || name.length > 100) {
          throw Exception('Name must be between 2 and 100 characters');
        }
        if (about.isEmpty || about.length < 10 || about.length > 1000) {
          throw Exception('About must be between 10 and 1000 characters');
        }
        
        int? age;
        if (ageText.isNotEmpty) {
          age = int.tryParse(ageText);
          if (age == null || age < 18 || age > 100) {
            throw Exception('Age must be a number between 18 and 100');
          }
        }
        
        final requestData = {
          'name': name,
          'about': about,
          if (age != null) 'age': age,
          if (creatorPhotoValue != null) 'photo': creatorPhotoValue,
          'categories': _selectedCategories.toList(),
        };
        
        debugPrint('📤 [EDIT PROFILE] Sending creator profile update:');
        debugPrint('   Name: $name (length: ${name.length})');
        debugPrint('   About: $about (length: ${about.length})');
        debugPrint('   Age: $age');
        debugPrint('   Photo: ${creatorPhotoValue != null ? "present" : "not provided"}');
        debugPrint('   Categories: ${_selectedCategories.toList()}');
        debugPrint('   Request data: $requestData');
        
        final creatorResponse = await _apiClient.patch(
          '/creator/profile',
          data: requestData,
        );

        if (creatorResponse.statusCode != 200) {
          throw Exception('Failed to save creator profile: ${creatorResponse.statusCode}');
        }
      }

      debugPrint('✅ [EDIT PROFILE] Profile saved successfully');

      await ref.read(authProvider.notifier).refreshUser();
      await ref.read(creatorsProvider.notifier).refreshFeed();
      await ref.read(usersProvider.notifier).refreshFeed();

      if (mounted) {
        AppToast.showSuccess(context, 'Profile updated successfully');
        context.pop();
      }
    } catch (e) {
      debugPrint('❌ [EDIT PROFILE] Error saving profile: $e');
      if (e is DioException) {
        debugPrint('   📦 Response data: ${e.response?.data}');
        debugPrint('   🔢 Status code: ${e.response?.statusCode}');
      }

      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t save profile. Please try again.',
          ),
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final availableAvatars = _getAvailableAvatars();
    final scheme = Theme.of(context).colorScheme;

    // Update selected avatar if it's not in the current list
    if (_selectedAvatar != null &&
        !availableAvatars.contains(_selectedAvatar!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedAvatar =
                availableAvatars.isNotEmpty ? availableAvatars[0] : null;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppBrandGradients.accountMenuPageBackground,
      appBar: buildBrandAppBar(
        context,
        title: 'Edit Profile',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar Selection — Only show for non-creators
                  if (user?.role != 'creator' && user?.role != 'admin') ...[
                    Text(
                      'Your Avatar',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Gallery preview (if a gallery image is selected) ──
                    if (_usingGalleryImage) ...[
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppBrandGradients
                                      .avatarCarouselSelectedBorder,
                                  width: AppBrandGradients
                                      .avatarCarouselSelectedBorderWidth,
                                ),
                                boxShadow: const [
                                  AppBrandGradients.avatarCarouselGlow,
                                ],
                              ),
                              child: ClipOval(
                                child: _galleryImageBytes != null
                                    ? Image.memory(
                                        _galleryImageBytes!,
                                        fit: BoxFit.cover,
                                        width: 130,
                                        height: 130,
                                      )
                                    : _buildCurrentAvatarUrl(user?.avatar),
                              ),
                            ),
                            // Small "change" button
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _pickFromGallery,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: scheme.surface, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: scheme.onPrimary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // "Use a preset avatar instead" link
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _usingGalleryImage = false;
                              _galleryImageBytes = null;
                              _galleryImageName = null;
                              _avatarChanged = true;
                            });
                          },
                          icon: Icon(Icons.grid_view,
                              size: 16, color: scheme.primary),
                          label: Text(
                            'Use a preset avatar instead',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // ── Preset Avatar Carousel ───────────────────────
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _selectedAvatar = availableAvatars[index];
                              _avatarChanged = true;
                            });
                          },
                          itemCount: availableAvatars.length,
                          itemBuilder: (context, index) {
                            final avatar = availableAvatars[index];
                            final isSelected = _selectedAvatar == avatar;

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _selectedAvatar = avatar;
                                  _avatarChanged = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Center(
                                  child: Container(
                                    width: isSelected ? 150 : 110,
                                    height: isSelected ? 150 : 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppBrandGradients
                                                .avatarCarouselSelectedBorder
                                            : AppBrandGradients
                                                .avatarCarouselUnselectedBorder,
                                        width: isSelected
                                            ? AppBrandGradients
                                                .avatarCarouselSelectedBorderWidth
                                            : AppBrandGradients
                                                .avatarCarouselUnselectedBorderWidth,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              AppBrandGradients
                                                  .avatarCarouselGlow,
                                            ]
                                          : null,
                                    ),
                                    child: ClipOval(
                                      child: FutureBuilder<String>(
                                        future: AvatarUploadService.getPresetAvatarUrl(
                                          avatarName: avatar,
                                          gender: user?.gender ?? 'male',
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data != null) {
                                            return Image.network(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: scheme.surfaceContainerHigh,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: scheme.onSurfaceVariant,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                          return Container(
                                            color: scheme.surfaceContainerHigh,
                                            child: Icon(
                                              Icons.person,
                                              color: scheme.onSurfaceVariant,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── "Or pick from gallery" button ──────────────
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: const Text('Pick from Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                            side: BorderSide(
                                color: scheme.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ] else ...[
                    // For creators – show avatar selection like regular users
                    Text(
                      'Your Profile Photo',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // ── Gallery preview (if a gallery image is selected) ──
                    if (_usingGalleryImage) ...[
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppBrandGradients
                                      .avatarCarouselSelectedBorder,
                                  width: AppBrandGradients
                                      .avatarCarouselSelectedBorderWidth,
                                ),
                                boxShadow: const [
                                  AppBrandGradients.avatarCarouselGlow,
                                ],
                              ),
                              child: ClipOval(
                                child: _galleryImageBytes != null
                                    ? Image.memory(
                                        _galleryImageBytes!,
                                        fit: BoxFit.cover,
                                        width: 130,
                                        height: 130,
                                      )
                                    : _buildCurrentAvatarUrl(user?.avatar),
                              ),
                            ),
                            // Small "change" button
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: _pickFromGallery,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: scheme.surface, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: scheme.onPrimary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // "Use a preset avatar instead" link
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _usingGalleryImage = false;
                              _galleryImageBytes = null;
                              _galleryImageName = null;
                              _avatarChanged = true;
                            });
                          },
                          icon: Icon(Icons.grid_view,
                              size: 16, color: scheme.primary),
                          label: Text(
                            'Use a preset avatar instead',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      // ── Preset Avatar Carousel ───────────────────────
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _selectedAvatar = availableAvatars[index];
                              _avatarChanged = true;
                            });
                          },
                          itemCount: availableAvatars.length,
                          itemBuilder: (context, index) {
                            final avatar = availableAvatars[index];
                            final isSelected = _selectedAvatar == avatar;

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() {
                                  _selectedAvatar = avatar;
                                  _avatarChanged = true;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Center(
                                  child: Container(
                                    width: isSelected ? 150 : 110,
                                    height: isSelected ? 150 : 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppBrandGradients
                                                .avatarCarouselSelectedBorder
                                            : AppBrandGradients
                                                .avatarCarouselUnselectedBorder,
                                        width: isSelected
                                            ? AppBrandGradients
                                                .avatarCarouselSelectedBorderWidth
                                            : AppBrandGradients
                                                .avatarCarouselUnselectedBorderWidth,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              AppBrandGradients
                                                  .avatarCarouselGlow,
                                            ]
                                          : null,
                                    ),
                                    child: ClipOval(
                                      child: FutureBuilder<String>(
                                        future: AvatarUploadService.getPresetAvatarUrl(
                                          avatarName: avatar,
                                          gender: user?.gender ?? 'male',
                                        ),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData &&
                                              snapshot.data != null) {
                                            return Image.network(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: scheme.surfaceContainerHigh,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: scheme.onSurfaceVariant,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                          return Container(
                                            color: scheme.surfaceContainerHigh,
                                            child: Icon(
                                              Icons.person,
                                              color: scheme.onSurfaceVariant,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── "Or pick from gallery" button ──────────────
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: const Text('Pick from Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.primary,
                            side: BorderSide(
                                color: scheme.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                    
                    // Creator-specific fields
                    if (user?.role == 'creator' || user?.role == 'admin') ...[
                      // Name Field
                      Text(
                        'Name *',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: scheme.onSurface),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: scheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: 'Enter your name',
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // About Field
                      Text(
                        'About *',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aboutController,
                        style: TextStyle(color: scheme.onSurface),
                        maxLines: 4,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: scheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: 'Tell users about yourself',
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Age Field
                      Text(
                        'Age',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ageController,
                        style: TextStyle(color: scheme.onSurface),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: scheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: 'Enter your age (18-100)',
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Creator Pictures (1-6) *',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_isGalleryLoading && _pendingGalleryPreviewBytes == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ..._creatorGalleryImages.map((image) {
                            final isDeleting = _galleryActionImageId == image.id;
                            final canRemove = _creatorGalleryImages.length >
                                1; // must keep ≥1 (matches save + backend)
                            return SizedBox(
                              width: 96,
                              height: 120,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        image.url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: scheme.surfaceContainerHigh,
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (canRemove)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: InkWell(
                                        onTap: isDeleting
                                            ? null
                                            : () =>
                                                _removeCreatorGalleryImage(image.id),
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: scheme.surface
                                                .withValues(alpha: 0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: isDeleting
                                              ? const Padding(
                                                  padding: EdgeInsets.all(4),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: scheme.error,
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          if (_pendingGalleryPreviewBytes != null)
                            SizedBox(
                              width: 96,
                              height: 120,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _pendingGalleryPreviewBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ColoredBox(
                                        color: scheme.shadow.withValues(alpha: 0.35),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_creatorGalleryImages.length < CreatorGalleryService.maxImages)
                            InkWell(
                              onTap: _isGalleryLoading ? null : _addCreatorGalleryImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 96,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: scheme.outlineVariant),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: scheme.primary),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload at least 1 and up to 6 pictures.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],

                  // Username Field
                  Text(
                    'Username *',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: scheme.outlineVariant, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: scheme.outlineVariant, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: scheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Username must be 4-10 characters.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Category Selection
                  Text(
                    'Select categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _categories.map((category) {
                      final isSelected =
                          _selectedCategories.contains(category);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCategories.remove(category);
                            } else {
                              if (_selectedCategories.length < 4) {
                                _selectedCategories.add(category);
                              } else {
                                AppToast.showInfo(
                                  context,
                                  'Maximum 4 categories allowed',
                                );
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: scheme.outlineVariant, width: 1),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scale(delay: 100.ms);
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'Select up to 4 categories (optional).',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    height: 56,
                    child: PrimaryButton(
                      label: 'Save',
                      onPressed: _isLoading ? null : _saveProfile,
                      isLoading: _isLoading,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────

  /// Show the current gallery-uploaded avatar from a URL.
  Widget _buildCurrentAvatarUrl(String? url) {
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 130,
        height: 130,
        errorBuilder: (_, __, ___) => _fallbackAvatar(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _fallbackAvatar();
        },
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 130,
      height: 130,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Icon(
        Icons.person,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}
