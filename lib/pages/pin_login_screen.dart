import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../home_screen.dart';
import 'phone_setup_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;

  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isPinValid = false;
  bool _isLoading = false;

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
    final pin = _pinControllers.map((c) => c.text).join('');
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

  Future<void> _handleLogin() async {
    final pin = _pinControllers.map((c) => c.text).join('');
    if (pin.length != 4) {
      _showError('Veuillez compléter le code PIN');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Récupérer les informations de l'utilisateur depuis SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone') ?? prefs.getString('reg_phone') ?? '';
      final countryId = prefs.getInt('user_country_id') ?? prefs.getInt('reg_country_id') ?? 0;

      if (phone.isEmpty || countryId == 0) {
        // Nettoyer les données temporaires et rediriger vers l'inscription
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_phone');
        await prefs.remove('user_country_id');
        await prefs.remove('reg_phone');
        await prefs.remove('reg_country_id');
        await prefs.remove('reg_user_id');
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PhoneSetupScreen()),
          );
        }
        return;
      }

      // Appeler l'API de connexion
      final result = await _apiService.login(
        phone: phone,
        countryId: countryId,
        pin: pin,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Connexion réussie - le token est déjà sauvegardé par l'API
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        // Erreur de connexion
        final message = result['message'] ?? 'PIN incorrect';
        _showError(message);
        setState(() => _isLoading = false);
        
        // Vider les champs PIN
        for (var controller in _pinControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        
        // Afficher un dialogue pour créer un nouveau compte
        _showCreateAccountDialog();
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur de connexion. Veuillez réessayer.');
        setState(() => _isLoading = false);
      }
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
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PIN incorrect'),
        content: const Text('Le PIN que vous avez entré est incorrect. Voulez-vous créer un nouveau compte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Réessayer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Nettoyer toutes les données
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_phone');
              await prefs.remove('user_country_id');
              await prefs.remove('reg_phone');
              await prefs.remove('reg_country_id');
              await prefs.remove('reg_user_id');
              
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const PhoneSetupScreen()),
                );
              }
            },
            child: const Text('Nouveau compte'),
          ),
        ],
      ),
    );
  }

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
                  const Color(0xFF6366F1).withOpacity(_backgroundAnimation.value * 0.1),
                  const Color(0xFF8B5CF6).withOpacity(_backgroundAnimation.value * 0.05),
                  const Color(0xFFF8F9FA),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _contentAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(-50 * (1 - _contentAnimation.value), 0),
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
                            offset: Offset(0, 30 * (1 - _contentAnimation.value)),
                            child: Opacity(
                              opacity: _contentAnimation.value,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.lock_outline,
                                        color: Color(0xFF6366F1), size: 40),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Connexion',
                                    style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1F2937),
                                        letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Entrez votre code PIN pour accéder à votre compte',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF6B7280),
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 48),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: List.generate(4, (i) => _buildPinField(i)),
                                  ),
                                  const SizedBox(height: 40),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isPinValid && !_isLoading
                                          ? _handleLogin
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text('Se connecter',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600)),
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
            color: Colors.black.withValues(alpha: 0.05),
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
