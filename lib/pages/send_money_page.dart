import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../home_screen.dart';
import 'history_page.dart';
import 'settings_page.dart';

class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({super.key});

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage>
    with TickerProviderStateMixin {
  final _recipientController = TextEditingController();
  final _amountController    = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset>  _slideAnimation;

  bool _isProcessing     = false;
  bool _isValidAmount    = false;
  bool _isValidRecipient = false;
  Timer? _validationTimer;
  Timer? _simulateTimer;

  // ─── Données pays / taux chargées depuis le back ─────────────────────────
  List<Map<String, dynamic>> _countries  = [];
  List<Map<String, dynamic>> _allRates   = [];
  bool _loadingCountries = true;

  // Pays expéditeur (pays du compte connecté)
  int?   _senderCountryId;

  // Pays destinataire sélectionné
  int?   _selectedCountryId;
  String _selectedCountryName = '';
  String _selectedCountryFlag = '';

  // Simulation
  Map<String, dynamic>? _preview;   // résultat de POST /transfers/simulate
  bool _loadingPreview = false;

  final ApiService _apiService = ApiService();

  // ─── Init ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();

    _recipientController.addListener(_validateForm);
    _amountController.addListener(_validateForm);
    _amountController.addListener(_scheduleSimulate);

    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _validationTimer?.cancel();
    _simulateTimer?.cancel();
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ─── Chargement initial : pays + taux + pays du sender ───────────────────

  Future<void> _loadInitialData() async {
    final prefs  = await SharedPreferences.getInstance();
    _senderCountryId = prefs.getInt('user_country_id');

    final results = await Future.wait([
      _apiService.getCountries(),
      _apiService.getExchangeRates(),
    ]);

    if (!mounted) return;

    final countriesResult = results[0];
    final ratesResult     = results[1];

    if (countriesResult['success'] == true) {
      final List<dynamic> data = countriesResult['data'] ?? [];
      final allCountries = data.map((c) => {
        'id':       c['id'],
        'name':     c['name']      ?? '',
        'dial_code':c['dial_code'] ?? '',
        'flag':     c['flag']      ?? '',
      }).toList().cast<Map<String, dynamic>>();

      // Exclure le pays de l'expéditeur de la liste destination
      final destinations = allCountries
          .where((c) => c['id'] != _senderCountryId)
          .toList();

      setState(() {
        _countries        = destinations;
        _loadingCountries = false;
        if (destinations.isNotEmpty) {
          _selectedCountryId   = destinations.first['id'] as int?;
          _selectedCountryName = destinations.first['name'] as String;
          _selectedCountryFlag = destinations.first['flag'] as String? ?? '';
        }
      });
    } else {
      setState(() => _loadingCountries = false);
    }

    if (ratesResult['success'] == true) {
      final List<dynamic> rates = ratesResult['data'] ?? [];
      setState(() => _allRates = rates.cast<Map<String, dynamic>>());
    }
  }

  // ─── Taux actif pour le corridor sélectionné ─────────────────────────────

  Map<String, dynamic>? get _activeRate {
    if (_senderCountryId == null || _selectedCountryId == null) return null;
    try {
      return _allRates.firstWhere(
        (r) =>
            r['from_country_id'] == _senderCountryId &&
            r['to_country_id']   == _selectedCountryId,
      );
    } catch (_) {
      return null;
    }
  }

  String get _senderCurrency =>
      _activeRate?['from_currency'] as String? ?? 'XAF';
  String get _receiverCurrency =>
      _activeRate?['to_currency'] as String? ?? '';
  double get _feePercent =>
      (_activeRate?['fee_percent'] as num?)?.toDouble() ?? 2.0;

  // ─── Validation formulaire ────────────────────────────────────────────────

  void _validateForm() {
    _validationTimer?.cancel();
    _validationTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _isValidRecipient = _recipientController.text.trim().isNotEmpty;
        final amount = double.tryParse(_amountController.text);
        _isValidAmount = amount != null && amount > 0 && amount <= 5000000;
      });
    });
  }

  // ─── Simulation en temps réel (appel API après 600 ms de pause) ──────────

  void _scheduleSimulate() {
    _simulateTimer?.cancel();
    if (_amountController.text.isEmpty) {
      setState(() => _preview = null);
      return;
    }
    _simulateTimer = Timer(const Duration(milliseconds: 600), () async {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0 || _selectedCountryId == null) return;

      setState(() => _loadingPreview = true);

      final result = await _apiService.simulateTransfer(
        toCountryId: _selectedCountryId!,
        amount:      amount,
      );

      if (!mounted) return;
      setState(() {
        _loadingPreview = false;
        _preview = result['success'] == true ? result['data'] as Map<String, dynamic>? : null;
      });
    });
  }

  // ─── Envoi ────────────────────────────────────────────────────────────────

  Future<void> _sendMoney() async {
    if (!_isValidRecipient || !_isValidAmount || _selectedCountryId == null) {
      _showErrorDialog('Veuillez remplir tous les champs correctement');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final result = await _apiService.sendTransfer(
      receiverPhone: _recipientController.text.trim(),
      toCountryId:   _selectedCountryId!,
      amount:        double.parse(_amountController.text),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      _showSuccessDialog(result['data'] as Map<String, dynamic>);
    } else {
      final errors = result['errors'] as Map<String, dynamic>?;
      final msg = errors?.values.first?.toString() ??
          result['message'] as String? ??
          'Une erreur est survenue.';
      _showErrorDialog(msg);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildRecipientInput(),
                          const SizedBox(height: 20),
                          _buildAmountInput(),
                          const SizedBox(height: 20),
                          _buildCountrySelector(),
                          const SizedBox(height: 20),
                          _buildFeeSummary(),
                          const SizedBox(height: 30),
                          _buildSendButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ─── Widgets (design original conservé) ──────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 16),
        Text(
          'Envoyer de l\'argent',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              letterSpacing: -0.5),
        ),
        SizedBox(height: 8),
        Text(
          'Transferts rapides et sécurisés',
          style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecipientInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
          color: _isValidRecipient
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _recipientController,
        keyboardType: TextInputType.phone,
        onChanged: (_) => HapticFeedback.lightImpact(),
        decoration: InputDecoration(
          labelText: 'Destinataire',
          hintText: 'Numéro de téléphone',
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.person_outlined,
                color: _isValidRecipient
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280)),
          ),
          suffixIcon: _isValidRecipient
              ? Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF10B981), size: 20))
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(
          color: _isValidAmount
              ? const Color(0xFF10B981).withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: TextInputType.number,
        onChanged: (_) => HapticFeedback.lightImpact(),
        decoration: InputDecoration(
          labelText: 'Montant ($_senderCurrency)',
          hintText: '0',
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.attach_money,
                color: _isValidAmount
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280)),
          ),
          suffixIcon: _isValidAmount
              ? Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF10B981), size: 20))
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(20),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
          helperText: _amountController.text.isNotEmpty && !_isValidAmount
              ? 'Montant invalide (max: 5 000 000)'
              : null,
          helperStyle:
              const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pays de destination',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 12),
            _loadingCountries
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ))
                : GestureDetector(
                    onTap: _showCountryDropdown,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB), width: 1),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCountryFlag.isNotEmpty
                                ? _selectedCountryFlag
                                : '🌍',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCountryName.isNotEmpty
                                      ? _selectedCountryName
                                      : 'Sélectionner',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937)),
                                ),
                                if (_receiverCurrency.isNotEmpty)
                                  Text(
                                    'Devise: $_receiverCurrency',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280)),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Color(0xFF6B7280), size: 20),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showCountryDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 20),
            const Text('Sélectionner le pays',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 20),
            ..._countries.map((country) {
              final isSelected = country['id'] == _selectedCountryId;
              // Taux pour ce corridor
              final rate = _allRates.cast<Map<String, dynamic>>()
                  .where((r) =>
                      r['from_country_id'] == _senderCountryId &&
                      r['to_country_id']   == country['id'])
                  .firstOrNull;
              final currency = rate?['to_currency'] as String? ?? '';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCountryId   = country['id'] as int?;
                    _selectedCountryName = country['name'] as String;
                    _selectedCountryFlag = country['flag'] as String? ?? '';
                    _preview             = null;
                  });
                  _scheduleSimulate();
                  Navigator.of(context).pop();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(country['flag'] as String? ?? '🌍',
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              country['name'] as String,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF1F2937)),
                            ),
                            if (currency.isNotEmpty)
                              Text('Devise: $currency',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF6366F1), size: 24),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeSummary() {
    // Si une simulation est disponible on l'utilise, sinon calcul local
    final amount     = double.tryParse(_amountController.text) ?? 0.0;
    final feeAmt     = _preview != null
        ? (_preview!['fee_amount'] as num?)?.toDouble() ?? (amount * _feePercent / 100)
        : amount * _feePercent / 100;
    final total      = _preview != null
        ? (_preview!['total_deducted'] as num?)?.toDouble() ?? amount + feeAmt
        : amount + feeAmt;
    final converted  = _preview != null
        ? (_preview!['amount_received'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final rate       = _preview != null
        ? (_preview!['exchange_rate'] as num?)?.toDouble() ?? 0.0
        : (_activeRate?['rate'] as num?)?.toDouble() ?? 0.0;
    final recvCcy    = _preview?['currency_received'] as String? ?? _receiverCurrency;
    final isCrossRate = recvCcy.isNotEmpty && recvCcy != _senderCurrency;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Résumé du transfert',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const Spacer(),
              if (_loadingPreview)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (recvCcy.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(recvCcy,
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Montant envoyé',
              '${amount.toStringAsFixed(2)} $_senderCurrency'),
          if (isCrossRate && converted > 0)
            _buildSummaryRow('Montant reçu',
                '${converted.toStringAsFixed(2)} $recvCcy'),
          _buildSummaryRow(
              'Frais ($_feePercent%)', '${feeAmt.toStringAsFixed(2)} $_senderCurrency'),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total débité',
            '${total.toStringAsFixed(2)} $_senderCurrency',
            isBold: true,
            color: const Color(0xFF6366F1),
          ),
          if (isCrossRate && converted > 0)
            _buildSummaryRow(
              'Total reçu',
              '${converted.toStringAsFixed(2)} $recvCcy',
              isBold: true,
              color: const Color(0xFF10B981),
            ),
          if (rate > 0 && isCrossRate) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF6B7280), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Taux: 1 $_senderCurrency = $rate $recvCcy',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280))),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  color: color ?? const Color(0xFF1F2937),
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = _isValidRecipient && _isValidAmount && !_isProcessing;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canSend
              ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
              : [const Color(0xFF9CA3AF), const Color(0xFFD1D5DB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: canSend
            ? [
                BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8))
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend ? _sendMoney : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isProcessing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              strokeWidth: 3)),
                      SizedBox(width: 12),
                      Text('Envoi en cours...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Envoyer l\'argent',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -8))
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Accueil', 0),
            _buildNavItem(Icons.swap_horiz_rounded, 'Transfert', 1,
                isActive: true),
            _buildNavItem(Icons.history_rounded, 'Historique', 2),
            _buildNavItem(Icons.person_rounded, 'Profil', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index,
      {bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 0) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const HistoryPage()));
        } else if (index == 3) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const SettingsPage()));
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF9CA3AF),
                size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF9CA3AF),
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs (design original conservé) ──────────────────────────────────

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Transfert réussi !',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 12),
              Text(
                '${data['amount_sent']} ${data['currency_sent']} envoyé à ${data['receiver_phone']}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              Text('Pays: ${data['to_country'] ?? _selectedCountryName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Réf: ${data['reference']}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForm();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Nouveau transfert',
                          style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Terminer',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Erreur',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937))),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    HapticFeedback.lightImpact();
    _recipientController.clear();
    _amountController.clear();
    setState(() {
      _isValidRecipient = false;
      _isValidAmount    = false;
      _preview          = null;
    });
  }
}