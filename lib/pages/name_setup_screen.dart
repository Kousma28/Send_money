import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'pin_setup_screen.dart';

class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({super.key});

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController  = TextEditingController();
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus  = FocusNode();

  bool _isLoading   = false;
  bool _isFormValid = false;

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

    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    super.dispose();
  }

  void _validateForm() {
    final isValid = _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty;
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  // ─── Soumission — Étape 2 ─────────────────────────────────────────────────

  Future<void> _continueToPin() async {
    if (!_isFormValid || _isLoading) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    // Récupérer le user_id sauvegardé à l'étape 1
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt('reg_user_id') ?? 0;

    final result = await _apiService.registerProfile(
      userId:    userId,
      firstName: _firstNameController.text.trim(),
      lastName:  _lastNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName':  _lastNameController.text.trim(),
        'fullName':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      };

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PinSetupScreen(userData: userData),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) =>
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeInOut)),
                    child: child,
                  ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(result['message'] ?? 'Une erreur est survenue.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1)
                      .withOpacity(_backgroundAnimation.value * 0.1),
                  const Color(0xFF8B5CF6)
                      .withOpacity(_backgroundAnimation.value * 0.05),
                  const Color(0xFFF8F9FA),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24.0,
                  right: 24.0,
                  top: 24.0,
                  bottom: 100.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _contentAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset:
                              Offset(-50 * (1 - _contentAnimation.value), 0),
                          child: Opacity(
                            opacity: _contentAnimation.value,
                            child: IconButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Color(0xFF6366F1), size: 24),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height - 200,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.person_outline,
                                      color: Color(0xFF6366F1), size: 40),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Bienvenue !',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                      letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Commençons par vous connaître\nQuel est votre nom ?',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF6B7280),
                                      height: 1.5),
                                ),
                                const SizedBox(height: 48),
                                _buildNameField(
                                  controller: _firstNameController,
                                  focusNode: _firstNameFocus,
                                  label: 'Prénom',
                                  hint: 'Entrez votre prénom',
                                  icon: Icons.person_outline,
                                  isFirstName: true,
                                ),
                                const SizedBox(height: 20),
                                _buildNameField(
                                  controller: _lastNameController,
                                  focusNode: _lastNameFocus,
                                  label: 'Nom',
                                  hint: 'Entrez votre nom de famille',
                                  icon: Icons.person,
                                  isFirstName: false,
                                ),
                                const SizedBox(height: 40),
                                AnimatedBuilder(
                                  animation: _contentAnimation,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(
                                          0,
                                          20 *
                                              (1 -
                                                  _contentAnimation.value)),
                                      child: Opacity(
                                        opacity: _contentAnimation.value,
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed: _isFormValid &&
                                                    !_isLoading
                                                ? _continueToPin
                                                : null,
                                            style:
                                                ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF6366F1),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shadowColor:
                                                  Colors.transparent,
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        16),
                                              ),
                                              disabledBackgroundColor:
                                                  const Color(0xFFE5E7EB),
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
                                                : const Text('Continuer',
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight
                                                                .w600)),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 40),
                              ],
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

  Widget _buildNameField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isFirstName,
  }) {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _contentAnimation.value)),
          child: Opacity(
            opacity: _contentAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: focusNode.hasFocus
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFE5E7EB),
                      width: 2,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: isFirstName
                        ? TextInputAction.next
                        : TextInputAction.done,
                    textAlign: TextAlign.start,
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    onSubmitted: (value) {
                      if (isFirstName) {
                        FocusScope.of(context)
                            .requestFocus(_lastNameFocus);
                      } else {
                        if (_isFormValid) _continueToPin();
                      }
                    },
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400),
                      prefixIcon: Icon(icon,
                          color: focusNode.hasFocus
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF9CA3AF),
                          size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}