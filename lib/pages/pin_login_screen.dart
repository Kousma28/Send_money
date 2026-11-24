import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  late AnimationController _errorModalController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;
  late Animation<double> _errorModalAnimation;

  final List<TextEditingController> _pinControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isPinValid = false;
  bool _isLoading = false;
  int _remainingAttempts = 3;
  bool _showErrorModal = false;

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
    _errorModalController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
    _contentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutQuart),
    );
    _errorModalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _errorModalController, curve: Curves.easeOutCubic),
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
    _errorModalController.dispose();
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
      // Si un caractère est ajouté, passer à la case suivante
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      // Si le caractère est supprimé (value.isEmpty), revenir à la case précédente
      _focusNodes[index].unfocus();
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
    _validatePin();
  }

  void _onKeyTap(int index, RawKeyEvent event) {
    // Détecter la touche d'effacement (backspace)
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_pinControllers[index].text.isEmpty && index > 0) {
        // Si la case actuelle est vide, focus sur la case précédente et effacer son contenu
        _focusNodes[index].unfocus();
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
        _pinControllers[index - 1].clear();
      }
    }
  }

  Future<void> _handleLogin() async {
    final pin = _pinControllers.map((c) => c.text).join('');
    if (pin.length != 4) {
      _showErrorModalWithMessage('Veuillez compléter le code PIN');
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
            PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => const PhoneSetupScreen(), transitionDuration: const Duration(milliseconds: 300), transitionsBuilder: (context, animation, secondaryAnimation, child) { return FadeTransition(opacity: animation, child: child); }),
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
        // Connexion réussie
        setState(() => _isLoading = false);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        // Erreur de connexion - PIN incorrect
        setState(() => _isLoading = false);
        
        // Décrémenter les tentatives restantes
        _remainingAttempts--;
        
        // Vider les champs PIN
        for (var controller in _pinControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        
        if (_remainingAttempts > 0) {
          // Afficher le modal avec le nombre de tentatives restantes
          _showErrorModalWithMessage('Il vous reste $_remainingAttempts tentative${_remainingAttempts > 1 ? 's' : ''}. Veuillez réessayer.');
        } else {
          // Plus de tentatives, rediriger vers création de compte
          _showErrorModalWithMessage('Vous avez épuisé toutes vos tentatives.');
          // Après 2 secondes, montrer le dialogue de création de compte
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop(); // Fermer le modal
              _showCreateAccountDialog();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorModalWithMessage('Erreur de connexion. Veuillez réessayer.');
      }
    }
  }

  void _showErrorModalWithMessage(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _showErrorModal = true;
    });
    _errorModalController.forward();
    
    // Afficher le message dans le modal via un paramètre
    // On utilisera un state pour stocker le message d'erreur
    _showErrorModalMessage(message);
  }
  
  void _showErrorModalMessage(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: _errorModalAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _errorModalAnimation.value,
            child: Opacity(
              opacity: _errorModalAnimation.value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Erreur',
                      style: AppText.serif(size: 20, weight: FontWeight.w600, color: AppColors.ink),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.inkMuted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.cardLine),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _showErrorModal = false;
                              });
                              _errorModalController.reverse();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.forestDark,
                              side: const BorderSide(color: AppColors.forestDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'OK',
                              style: AppText.sans(size: 14, weight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _showErrorModal = false;
                              });
                              _errorModalController.reverse();
                              _showForgotPasswordDialog();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forestDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text(
                              'Mot de passe oublié',
                              style: AppText.sans(size: 14, weight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
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

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text('Mot de passe oublié', style: AppText.serif(size: 20, weight: FontWeight.w600, color: AppColors.ink)),
        content: Text(
          'Veuillez contacter le support pour réinitialiser votre mot de passe.',
          style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.inkMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer', style: AppText.sans(weight: FontWeight.w600, color: AppColors.forestDark)),
          ),
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text('Compte bloqué', style: AppText.serif(size: 20, weight: FontWeight.w600, color: AppColors.ink)),
        content: Text(
          'Vous avez épuisé toutes vos tentatives. Voulez-vous créer un nouveau compte ?',
          style: AppText.sans(size: 14, weight: FontWeight.w500, color: AppColors.inkMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: AppText.sans(weight: FontWeight.w600, color: AppColors.inkMuted)),
          ),
          ElevatedButton(
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
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const PhoneSetupScreen(),
                    transitionDuration: const Duration(milliseconds: 300),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Nouveau compte', style: AppText.sans(weight: FontWeight.w600, color: Colors.white)),
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
                  AppColors.forestDark.withOpacity(_backgroundAnimation.value * 0.1),
                  AppColors.gold.withOpacity(_backgroundAnimation.value * 0.06),
                  AppColors.bg,
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
                    const SizedBox(height: 20),
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.forestDark.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.lock_outline,
                                        color: AppColors.forestDark, size: 40),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Connexion',
                                    style: AppText.serif(size: 28, weight: FontWeight.w600, color: AppColors.ink, letterSpacing: -0.3),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Entrez votre code PIN pour accéder à votre compte',
                                    style: AppText.sans(size: 16, weight: FontWeight.w500, color: AppColors.inkMuted, height: 1.5),
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
                                        backgroundColor: AppColors.forestDark,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        disabledBackgroundColor: AppColors.cardLine,
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
                                          : Text('Se connecter',
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
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyTap(index, event),
        child: TextField(
          controller: _pinControllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          maxLength: 1,
          obscureText: true,
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
      ),
    );
  }
}