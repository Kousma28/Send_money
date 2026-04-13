import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PinConfirmScreen extends StatefulWidget {
  final String pin;

  const PinConfirmScreen({super.key, required this.pin});

  @override
  State<PinConfirmScreen> createState() => _PinConfirmScreenState();
}

class _PinConfirmScreenState extends State<PinConfirmScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(4, (_) => FocusNode());

  bool _isPinValid    = false;
  bool _isLoading     = false;
  bool _isPinMatching = true;

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

    for (var c in _pinControllers) c.addListener(_validatePin);
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
    if (_isPinValid != isValid) {
      setState(() {
        _isPinValid    = isValid;
        _isPinMatching = true;
      });
    }
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }
    _validatePin();
  }

  // ─── Soumission — Étape 4 ─────────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    final enteredPin = _pinControllers.map((c) => c.text).join('');

    if (enteredPin.length != 4) {
      _showError('Veuillez compléter le code PIN');
      return;
    }

    // Vérification locale avant l'appel API
    if (enteredPin != widget.pin) {
      setState(() {
        _isPinMatching = false;
        _isPinValid    = false;
      });
      for (var c in _pinControllers) c.clear();
      _focusNodes[0].requestFocus();
      _showError('Les codes PIN ne correspondent pas');
      return;
    }

    setState(() => _isLoading = true);

    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getInt('reg_user_id') ?? 0;

    // Appel API — POST /api/register/confirm-pin
    final result = await _apiService.confirmPin(
      userId:          userId,
      pin:             widget.pin,
      pinConfirmation: enteredPin,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Nettoyer le user_id temporaire
      await prefs.remove('reg_user_id');

      _showSuccessAndNavigate();
    } else {
      // Erreur renvoyée par le serveur (PIN non concordant, session expirée…)
      setState(() {
        _isPinMatching = false;
        _isPinValid    = false;
      });
      for (var c in _pinControllers) c.clear();
      _focusNodes[0].requestFocus();
      _showError(result['message'] ?? 'Une erreur est survenue.');
    }
  }

  void _showSuccessAndNavigate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Inscription réussie !')),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Sauvegarder les informations de l'utilisateur pour la prochaine connexion
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('reg_phone') ?? '';
    final countryId = prefs.getInt('reg_country_id') ?? 0;
    
    if (phone.isNotEmpty && countryId > 0) {
      await prefs.setString('user_phone', phone);
      await prefs.setInt('user_country_id', countryId);
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    });
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
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                color: Color(0xFF6366F1), size: 24),
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
                                      color: const Color(0xFF6366F1)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.lock_outline,
                                        color: Color(0xFF6366F1),
                                        size: 40),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Confirmez votre code PIN',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                        letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Entrez à nouveau votre code PIN à 4 chiffres pour confirmer',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 48),
                                  if (!_isPinMatching)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(
                                          bottom: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: Color(0xFFEF4444),
                                              size: 20),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Les codes PIN ne correspondent pas. Veuillez réessayer.',
                                              style: TextStyle(
                                                  color:
                                                      Color(0xFFEF4444),
                                                  fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                          ? _handleConfirm
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16)),
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
                                          : const Text('Confirmer',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w600)),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? const Color(0xFF6366F1)
              : const Color(0xFFE5E7EB),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        onChanged: (value) => _onPinChanged(index, value),
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937)),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}