import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/user_message_mapper.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/services/avatar_upload_service.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

class GenderSelectionScreen extends ConsumerStatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  ConsumerState<GenderSelectionScreen> createState() =>
      _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends ConsumerState<GenderSelectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _selectedGender;
  String? _selectedAvatar;
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _defaultAvatarForGender(String gender) {
    return AvatarUploadService.getDefaultAvatarName(gender);
  }

  Future<void> _saveProfile() async {
    // ── Validate name ───────────────────────────────────────────────────
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showValidationHint('Please enter your name');
      return;
    }
    if (name.length < 4 || name.length > 10) {
      _showValidationHint('Name must be 4–10 characters');
      return;
    }

    // ── Validate gender ─────────────────────────────────────────────────
    if (_selectedGender == null) {
      _showValidationHint('Please select your gender');
      return;
    }

    // ── Validate age ────────────────────────────────────────────────────
    final ageText = _ageController.text.trim();
    if (ageText.isEmpty) {
      _showValidationHint('Please enter your age');
      return;
    }
    final age = int.tryParse(ageText);
    if (age == null || age < 13 || age > 120) {
      _showValidationHint('Please enter a valid age (13-120)');
      return;
    }

    // ── Validate avatar ─────────────────────────────────────────────────
    if (_selectedAvatar == null) {
      _showValidationHint('Please select an avatar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('───────────────────────────────────────────────────────');
      debugPrint('🔄 [ONBOARDING] Saving profile...');
      debugPrint('   Name: $name');
      debugPrint('   Age: $age');
      debugPrint('   Gender: $_selectedGender');
      debugPrint('   Avatar: $_selectedAvatar');

      // 1. Resolve preset avatar URL from Firebase Storage
      debugPrint('🖼️  [ONBOARDING] Resolving preset avatar URL...');
      final avatarUrl = await AvatarUploadService.getPresetAvatarUrl(
        avatarName: _selectedAvatar!,
        gender: _selectedGender!,
      );
      debugPrint('✅ [ONBOARDING] Preset avatar URL resolved: $avatarUrl');

      // 2. Save everything to backend in a single call
      final response = await _apiClient.put(
        '/user/profile',
        data: {
          'gender': _selectedGender,
          'username': name,
          'age': age,
          'avatar': avatarUrl,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [ONBOARDING] Profile saved successfully');

        // Refresh user data in auth provider
        await ref.read(authProvider.notifier).refreshUser();

        if (mounted) context.go('/home');
      } else {
        throw Exception('Failed to save profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [ONBOARDING] Error: $e');
      if (mounted) {
        AppToast.showError(
          context,
          UserMessageMapper.userMessageFor(
            e,
            fallback: 'Couldn\'t save profile. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showValidationHint(String message) {
    AppToast.showInfo(context, message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);
    final bool canContinue =
        _nameController.text.trim().length >= 4 &&
        age != null && age >= 13 && age <= 120 &&
        _selectedGender != null &&
        _selectedAvatar != null;

    return Scaffold(
      backgroundColor: const Color(0xFF2D1B3D),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2D1B3D),
              const Color(0xFF3D2B4D),
              const Color(0xFF2D1B3D),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // ── Title ──────────────────────────────────────────
                  Text(
                    'Tell us about yourself',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 28,
                        ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 8),

                  Text(
                    "Let's get you set up",
                    style: TextStyle(color: Colors.grey[300], fontSize: 16),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 40),

                  // ── Name field ─────────────────────────────────────
                  Text(
                    'Your Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLength: 10,
                    onChanged: (_) => setState(() {}), // rebuild for button state
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      counterStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms),

                  const SizedBox(height: 8),

                  Text(
                    '4–10 characters',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),

                  const SizedBox(height: 32),

                  // ── Gender selection ────────────────────────────────
                  Text(
                    'Select your gender',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 250.ms),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildGenderChip(
                          icon: Icons.male,
                          label: 'Male',
                          value: 'male',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildGenderChip(
                          icon: Icons.female,
                          label: 'Female',
                          value: 'female',
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // ── Age field ────────────────────────────────────────
                  Text(
                    'Your Age',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 350.ms),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLength: 3,
                    onChanged: (_) => setState(() {}), // rebuild for button state
                    decoration: InputDecoration(
                      hintText: 'Enter your age',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      counterStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    '13-120 years',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),

                  const SizedBox(height: 32),

                  // ── Continue button ────────────────────────────────
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (canContinue ? _saveProfile : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canContinue ? Colors.white : Colors.grey[600],
                        foregroundColor: canContinue
                            ? const Color(0xFF2D1B3D)
                            : Colors.grey[400],
                        disabledBackgroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const LoadingIndicator()
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 400.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENDER CHIP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGenderChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isSelected = _selectedGender == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
          _selectedAvatar = _defaultAvatarForGender(value);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.12),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }

}
