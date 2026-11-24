import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pin_confirm_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final Map<String, String>? userData;

  const PinSetupScreen({super.key, this.userData});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(4, (_) => FocusNode());

  bool _isPinValid = false;
  bool _isLoading  = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutQuart),
    );

    _backgroundController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentController.forward();
    });

    for (var c in _pinControllers) {
      c.addListener(_validatePin);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    for (var c in _pinControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _validatePin() {
    final pin    = _pinControllers.map((c) => c.text).join('');
    final isValid = pin.length == 4;
    if (_isPinValid != isValid) setState(() => _isPinValid = isValid);
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }
    _validatePin();
  }

  // ─── Soumission — Étape 3 ─────────────────────────────────────────────────

  Future<void> _handleContinue() async {
    final pin = _pinControllers.map((c) => c.text).join('');
    if (pin.length != 4) {
      _showError('Veuillez compléter le code PIN');
      return;
    }

    setState(() => _isLoading = true);

    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt('reg_user_id') ?? 0;

    final result = await _apiService.registerPin(userId: userId, pin: pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PinConfirmScreen(pin: pin),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      _showError(result['message'] ?? 'Une erreur est survenue.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.forestDark
                      .withOpacity(_backgroundAnimation.value * 0.1),
                  AppColors.gold
                      .withOpacity(_backgroundAnimation.value * 0.06),
                  AppColors.bg,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 24.0, right: 24.0, top: 24.0, bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _contentAnimation,
                      builder: (context, child) => Transform.translate(
                        offset:
                            Offset(-50 * (1 - _contentAnimation.value), 0),
                        child: Opacity(
                          opacity: _contentAnimation.value,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios,
                                color: AppColors.forestDark, size: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: AnimatedBuilder(
                          animation: _contentAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                                0, 30 * (1 - _contentAnimation.value)),
                            child: Opacity(
                              opacity: _contentAnimation.value,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.forestDark
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.lock_outline,
                                        color: AppColors.forestDark,
                                        size: 40),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Créez votre code PIN',
                                    style: AppText.serif(size: 28, weight: FontWeight.w600, color: AppColors.ink, letterSpacing: -0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choisissez un code PIN à 4 chiffres pour sécuriser votre compte',
                                    style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.inkMuted, height: 1.5),
                                  ),
                                  const SizedBox(height: 48),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(
                                        4, (i) => _buildPinField(i)),
                                  ),
                                  const SizedBox(height: 40),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isPinValid && !_isLoading
                                          ? _handleContinue
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.forestDark,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        disabledBackgroundColor:
                                            AppColors.cardLine,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Colors.white),
                                              ),
                                            )
                                          : Text('Continuer',
                                              style: AppText.sans(size: 16, weight: FontWeight.w600, color: Colors.white)),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDark.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? AppColors.gold
              : AppColors.cardLine,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enableSuggestions: false,
        autocorrect: false,
        onChanged: (value) => _onPinChanged(index, value),
        style: AppText.serif(size: 24, weight: FontWeight.bold, color: AppColors.ink),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}