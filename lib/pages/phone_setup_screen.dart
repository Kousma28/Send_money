import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'name_setup_screen.dart';

class PhoneSetupScreen extends StatefulWidget {
  const PhoneSetupScreen({super.key});

  @override
  State<PhoneSetupScreen> createState() => _PhoneSetupScreenState();
}

class _PhoneSetupScreenState extends State<PhoneSetupScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;

  final TextEditingController _phoneController = TextEditingController();

  // ─── État pays ────────────────────────────────────────────────────────────
  // La liste est chargée depuis le back-end via GET /api/countries.
  // Jusqu'à la fin du chargement on affiche un indicateur.
  List<Map<String, dynamic>> _countries = [];
  bool _loadingCountries = true;

  int?    _selectedCountryId;
  String  _selectedCountryName = '';
  String  _selectedCountryCode = '';
  String  _selectedCountryFlag = '';

  bool _isFormValid = false;
  bool _isLoading   = false;

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

    _phoneController.addListener(_validateForm);
    _loadCountries();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─── Chargement des pays depuis le back ───────────────────────────────────

  Future<void> _loadCountries() async {
    // Liste de pays par défaut simplifiée (RDC, Congo, Sénégal)
    final defaultCountries = [
      {'id': 1, 'name': 'République Démocratique du Congo', 'dial_code': '+243', 'flag': '🇨🇩'},
      {'id': 2, 'name': 'République du Congo', 'dial_code': '+242', 'flag': '🇨🇬'},
      {'id': 3, 'name': 'Sénégal', 'dial_code': '+221', 'flag': '🇸🇳'},
    ];

    try {
      final result = await _apiService.getCountries();

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final countries = data.map((c) => {
          'id':        c['id'],
          'name':      c['name']      ?? '',
          'dial_code': c['dial_code'] ?? '',
          'flag':      c['flag']      ?? '',
        }).toList().cast<Map<String, dynamic>>();

        setState(() {
          _countries        = countries;
          _loadingCountries = false;

          // Pré-sélectionner le premier pays si la liste n'est pas vide
          if (countries.isNotEmpty) {
            final first          = countries.first;
            _selectedCountryId   = first['id'] as int?;
            _selectedCountryName = first['name']      as String;
            _selectedCountryCode = first['dial_code'] as String;
            _selectedCountryFlag = first['flag']      as String;
          }
        });
      } else {
        // Utiliser la liste par défaut en cas d'échec de l'API
        _useDefaultCountries(defaultCountries);
      }
    } catch (e) {
      // Utiliser la liste par défaut en cas d'erreur de connexion
      _useDefaultCountries(defaultCountries);
    }
  }

  void _useDefaultCountries(List<Map<String, dynamic>> defaultCountries) {
    if (!mounted) return;
    
    setState(() {
      _countries        = defaultCountries;
      _loadingCountries = false;

      // Pré-sélectionner le RDC (premier pays)
      if (defaultCountries.isNotEmpty) {
        final first          = defaultCountries.first;
        _selectedCountryId   = first['id'] as int?;
        _selectedCountryName = first['name']      as String;
        _selectedCountryCode = first['dial_code'] as String;
        _selectedCountryFlag = first['flag']      as String;
      }
    });
  }

  // ─── Validation ───────────────────────────────────────────────────────────

  void _validateForm() {
    final isValid = _phoneController.text.length >= 9 &&
        _selectedCountryId != null;
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  // ─── Soumission — Étape 1 ─────────────────────────────────────────────────

  Future<void> _continueToName() async {
    if (!_isFormValid || _isLoading) return;

    setState(() => _isLoading = true);

    final result = await _apiService.registerPhone(
      phone:     _phoneController.text.trim(),
      countryId: _selectedCountryId!,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Conserver le user_id pour les étapes suivantes
      final userId = result['data']?['user_id'] as int?;
      final prefs  = await SharedPreferences.getInstance();
      await prefs.setInt('reg_user_id', userId ?? 0);
      
      // Sauvegarder téléphone et pays pour la connexion future
      await prefs.setString('reg_phone', _phoneController.text.trim());
      await prefs.setInt('reg_country_id', _selectedCountryId!);

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const NameSetupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 800),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Configuration',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildForm(),
              const SizedBox(height: 40),
              _buildContinueButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.phone_android,
                      color: Color(0xFF6366F1), size: 30),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vérification du téléphone',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entrez votre numéro de téléphone et sélectionnez votre pays pour continuer',
                  style: TextStyle(
                      fontSize: 16, color: Color(0xFF6B7280), height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForm() {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _contentAnimation.value)),
          child: Opacity(
            opacity: _contentAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pays',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 12),
                  _buildCountrySelector(),
                  const SizedBox(height: 24),
                  const Text('Numéro de téléphone',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937))),
                  const SizedBox(height: 12),
                  _buildPhoneField(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loadingCountries
          ? const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Chargement des pays…'),
            )
          : ListTile(
              leading: Text(
                _selectedCountryFlag.isNotEmpty ? _selectedCountryFlag : '🌍',
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(_selectedCountryName.isNotEmpty
                  ? _selectedCountryName
                  : 'Sélectionner un pays'),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: _countries.isNotEmpty ? _showCountrySelector : null,
            ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _phoneController.text.isEmpty
              ? const Color(0xFFE5E7EB)
              : (_phoneController.text.length >= 9
                  ? Colors.green
                  : Colors.red),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Text(
              _selectedCountryCode.isNotEmpty ? _selectedCountryCode : '—',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: const InputDecoration(
                hintText: 'Entrez votre numéro',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 60 * (1 - _contentAnimation.value)),
          child: Opacity(
            opacity: _contentAnimation.value,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _isFormValid && !_isLoading ? _continueToName : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                  disabledBackgroundColor:
                      const Color(0xFF6366F1).withValues(alpha: 0.5),
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Continuer',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Bottom sheet sélection pays ─────────────────────────────────────────

  void _showCountrySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                children: [
                  const Text('Sélectionner un pays',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _countries.length,
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  final isSelected =
                      country['id'] == _selectedCountryId;
                  return ListTile(
                    leading: Text(
                      country['flag'] as String? ?? '🌍',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(country['name'] as String? ?? ''),
                    subtitle:
                        Text(country['dial_code'] as String? ?? ''),
                    trailing: isSelected
                        ? const Icon(Icons.check,
                            color: Color(0xFF6366F1))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCountryId   = country['id']       as int?;
                        _selectedCountryName = country['name']      as String;
                        _selectedCountryCode = country['dial_code'] as String;
                        _selectedCountryFlag = country['flag']      as String? ?? '';
                      });
                      _validateForm();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}