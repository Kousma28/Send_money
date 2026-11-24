import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'theme/app_theme.dart';
import 'pages/send_money_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'pages/qr_scanner_page.dart';
import 'services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ─── Navigation & UI ──────────────────────────────────────────
  int _currentIndex = 0;
  bool _isBalanceVisible = true;

  // ─── Animations ───────────────────────────────────────────────
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _carouselController;
  late AnimationController _qrModalController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _carouselAnimation;
  late Animation<double> _qrModalAnimation;

  // ─── Services ─────────────────────────────────────────────────
  final ApiService _apiService = ApiService();

  // ─── Profil utilisateur ───────────────────────────────────────
  String _userName = 'Chargement...';
  String _userFirstName = '';
  String _userLastName = '';
  String _userPhone = '';
  int? _userId;
  String _profileImagePath = '';
  bool _isLoadingProfile = true;

  // ─── Solde wallet ─────────────────────────────────────────────
  double _balance = 0.0;
  String _currency = 'XAF';
  bool _isLoadingBalance = true;

  // ─── Transactions ─────────────────────────────────────────────
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _isLoadingTransactions = true;

  // ─── QR Modal ─────────────────────────────────────────────────
  bool _showQRModal = false;
  int _qrModalMode = 0; // 0 = mon QR, 1 = scanner

  // ─── Carousel promo ───────────────────────────────────────────
  int _currentCarouselIndex = 0;
  late PageController _pageController;
  Timer? _carouselTimer;

  final List<Map<String, dynamic>> _promoItems = [
    {
      'title': '10% de Cashback',
      'subtitle': 'Sur tous les transferts',
      'description': 'Cette semaine uniquement',
      'icon': '💰',
      'color': '0xFFC9A227',
      'cta': 'Profiter',
      'bgGradient': ['0xFF0B3D2E', '0xFF1E7A52'],
      'badge': 'Limitée',
    },
    {
      'title': 'Transferts Gratuits',
      'subtitle': '0% de frais',
      'description': 'Aujourd\'hui seulement',
      'icon': '🚀',
      'color': '0xFF8A6B3A',
      'cta': 'Envoyer',
      'bgGradient': ['0xFFC9A227', '0xFF8A6B3A'],
      'badge': 'Flash',
    },
    {
      'title': 'Parrainez et Gagnez',
      'subtitle': '50 000 FCFA par ami',
      'description': 'Gagnez sans limite',
      'icon': '🎁',
      'color': '0xFFB9583F',
      'cta': 'Inviter',
      'bgGradient': ['0xFFB9583F', '0xFF7A3B2A'],
      'badge': 'Populaire',
    },
  ];

  // ══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _carouselController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _qrModalController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _carouselAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _carouselController, curve: Curves.easeInOut));
    _qrModalAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _qrModalController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();

    _pageController = PageController(viewportFraction: 0.9);
    _startCarouselAutoScroll();

    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _carouselController.dispose();
    _qrModalController.dispose();
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  // CHARGEMENT DES DONNÉES
  // ══════════════════════════════════════════════════════════════

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadWallet(),
      _loadTransactions(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final result = await _apiService.getMe();
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final rawData = result['data'] as Map<String, dynamic>;
        // Le UserResource peut être encapsulé dans 'user' ou à la racine
        final user = (rawData['user'] ?? rawData) as Map<String, dynamic>;

        setState(() {
          _userId = user['id'] as int?;
          _userFirstName = user['first_name'] as String? ?? '';
          _userLastName = user['last_name'] as String? ?? '';
          _userPhone = user['phone'] as String? ?? '';
          _userName = '$_userFirstName $_userLastName'.trim();
          _profileImagePath = user['profile_image'] as String? ?? '';
          _isLoadingProfile = false;
        });
      } else {
        await _loadProfileFromCache();
      }
    } catch (e) {
      await _loadProfileFromCache();
    }
  }

  Future<void> _loadProfileFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _userFirstName = prefs.getString('temp_first_name') ?? '';
        _userLastName = prefs.getString('temp_last_name') ?? '';
        _userPhone = prefs.getString('temp_phone') ?? '';
        _userId = prefs.getInt('temp_user_id');
        _userName = '$_userFirstName $_userLastName'.trim();
        _profileImagePath = prefs.getString('profile_image') ?? '';
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Utilisateur';
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadWallet() async {
    try {
      final result = await _apiService.getWallet();
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          _currency = data['currency'] as String? ?? 'XAF';
          _isLoadingBalance = false;
        });
      } else {
        setState(() => _isLoadingBalance = false);
      }
    } catch (e) {
      debugPrint('Erreur wallet: $e');
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final result = await _apiService.getTransfers(page: 1);
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> raw = result['data'] as List<dynamic>;

        final transactions = raw
            .take(5)
            .map<Map<String, dynamic>>(
                (t) => _mapTransferToUI(t as Map<String, dynamic>))
            .toList();

        setState(() {
          _recentTransactions = transactions;
          _isLoadingTransactions = false;
        });
      } else {
        setState(() => _isLoadingTransactions = false);
      }
    } catch (e) {
      debugPrint('Erreur transactions: $e');
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS DE MAPPING
  // ══════════════════════════════════════════════════════════════

  Map<String, dynamic> _mapTransferToUI(Map<String, dynamic> t) {
    final type = t['type'] as String? ?? 'sent';
    final isCredit = type == 'received';
    final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

    return {
      'name': t['name'] ?? 'Inconnu',
      'amount': isCredit ? amount : -amount,
      'date': _formatTransferDate(t['created_at']),
      'isCredit': isCredit,
      'status': _statusLabel(t['status'] as String? ?? 'pending'),
      'flag': _flagFromCountry(t['flag'] as String?),
      'country': t['country'] ?? '',
    };
  }

  String _formatTransferDate(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return '';

    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return 'Aujourd\'hui, $h:$m';
    } else if (diff.inDays == 1) {
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return 'Hier, $h:$m';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} j';
    }
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d/$mo/${local.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Complété';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échoué';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _flagFromCountry(String? flag) {
    if (flag == null || flag.isEmpty) return '🌍';
    if (flag.length <= 3) {
      const map = {
        'SN': '🇸🇳', 'CD': '🇨🇩', 'CG': '🇨🇬', 'CI': '🇨🇮',
        'CM': '🇨🇲', 'ML': '🇲🇱', 'BF': '🇧🇫', 'TG': '🇹🇬',
        'GN': '🇬🇳', 'GA': '🇬🇦', 'BJ': '🇧🇯', 'NE': '🇳🇪',
        'XOF': '🌍', 'XAF': '🌍', 'USD': '🌍', 'EUR': '🇪🇺',
      };
      return map[flag.toUpperCase()] ?? '🌍';
    }
    return flag;
  }

  String _formatBalance(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  String _formatAmount(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000) return '${(abs / 1000000).toStringAsFixed(1)}M';
    if (abs >= 1000) return '${(abs / 1000).toStringAsFixed(0)}K';
    return abs.toStringAsFixed(0);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _buildQRPayload() {
    if (_userId == null) return 'Utilisateur';
    return jsonEncode({
      'user_id': _userId,
      'phone': _userPhone,
      'name': _userName,
    });
  }

  // ══════════════════════════════════════════════════════════════
  // CAROUSEL AUTO-SCROLL
  // ══════════════════════════════════════════════════════════════

  void _startCarouselAutoScroll() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients && _promoItems.isNotEmpty) {
        int nextIndex = _currentCarouselIndex + 1;
        if (nextIndex >= _promoItems.length) nextIndex = 0;
        _currentCarouselIndex = nextIndex;
        _pageController.animateToPage(
          _currentCarouselIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.forestDark,
              onRefresh: _loadInitialData,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildPremiumMainCard(),
                        const SizedBox(height: 32),
                        _buildPromoCarousel(),
                        const SizedBox(height: 32),
                        _buildTransactionsSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showQRModal) _buildQRModal(),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEADER (avatar + greeting)
  // ══════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.forestDark, AppColors.forestDarker],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 2),
          ),
          child: _profileImagePath.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    _profileImagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  ),
                )
              : _buildDefaultAvatar(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              _isLoadingProfile
                  ? Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.cardLine,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      _userName.isNotEmpty ? _userName : 'Utilisateur',
                      style: AppText.serif(
                        size: 18,
                        weight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            ).then((_) {
              // Refresh au retour des settings
              if (mounted) _loadUserProfile();
            });
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardLine, width: 1),
            ),
            child: const Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour 👋';
    if (hour < 18) return 'Bon après-midi ☀️';
    return 'Bonsoir 🌙';
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        _getInitials(_userName),
        style: AppText.sans(
            size: 16, weight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CARTE PRINCIPALE (solde + QR)
  // ══════════════════════════════════════════════════════════════

  Widget _buildPremiumMainCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.forestDark,
            AppColors.forestDarker,
            Color(0xFF041A13),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDark.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.12), width: 1),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Solde disponible',
                        style: AppText.sans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.65))),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _isLoadingBalance
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _isBalanceVisible
                                    ? _formatBalance(_balance)
                                    : '••••••',
                                style: AppText.serif(
                                  size: 34,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing:
                                      _isBalanceVisible ? 0 : 3.0,
                                ),
                              ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(
                              () => _isBalanceVisible = !_isBalanceVisible),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currency,
                      style: AppText.sans(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.goldLight),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _showQRModal = true;
                    _qrModalMode = 0;
                  });
                  _qrModalController.forward();
                },
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.4), width: 1.5),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: _buildQRPayload(),
                      version: QrVersions.auto,
                      size: 70,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.forestDark,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PROMO CAROUSEL
  // ══════════════════════════════════════════════════════════════

  Widget _buildPromoCarousel() {
    if (_promoItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Offres du moment',
                  style: AppText.serif(
                      size: 20,
                      weight: FontWeight.w600,
                      color: AppColors.ink)),
              GestureDetector(
                onTap: () => HapticFeedback.lightImpact(),
                child: Row(
                  children: [
                    Text('Voir plus',
                        style: AppText.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.terracotta)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.terracotta),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              if (index >= 0 && index < _promoItems.length) {
                setState(() => _currentCarouselIndex = index);
                _carouselController.forward(from: 0);
              }
            },
            itemCount: _promoItems.length,
            itemBuilder: (context, index) {
              final promo = _promoItems[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(int.parse(
                          promo['bgGradient'][0].substring(2),
                          radix: 16)),
                      Color(int.parse(
                          promo['bgGradient'][1].substring(2),
                          radix: 16)),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(promo['icon'],
                              style: const TextStyle(fontSize: 26)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(promo['badge'],
                                style: AppText.sans(
                                    size: 10,
                                    weight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(promo['title'],
                          style: AppText.serif(
                              size: 20,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(promo['subtitle'],
                          style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.85))),
                      Text(promo['description'],
                          style: AppText.sans(
                              size: 11,
                              weight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.65))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          promo['cta'],
                          style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Color(int.parse(
                                  promo['color'].substring(2),
                                  radix: 16))),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promoItems.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: _currentCarouselIndex == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentCarouselIndex == index
                    ? AppColors.gold
                    : AppColors.cardLine,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ══════════════════════════════════════════════════════════════

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transactions récentes',
                  style: AppText.serif(
                      size: 20,
                      weight: FontWeight.w600,
                      color: AppColors.ink)),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryPage()),
                  ).then((_) {
                    if (mounted) {
                      _loadWallet();
                      _loadTransactions();
                    }
                  });
                },
                child: Row(
                  children: [
                    Text('Voir tout',
                        style: AppText.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.terracotta)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.terracotta, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardLine, width: 1),
          ),
          child: _isLoadingTransactions
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.forestDark),
                  ),
                )
              : _recentTransactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 42, color: AppColors.inkMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune transaction pour le moment',
                            textAlign: TextAlign.center,
                            style: AppText.sans(
                                size: 14,
                                weight: FontWeight.w500,
                                color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0;
                            i < _recentTransactions.length;
                            i++)
                          _buildTransactionItem(
                            _recentTransactions[i],
                            isLast:
                                i == _recentTransactions.length - 1,
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(
    Map<String, dynamic> transaction, {
    required bool isLast,
  }) {
    final isCredit = transaction['isCredit'] as bool;
    final statusColor = transaction['status'] == 'Complété'
        ? AppColors.success
        : transaction['status'] == 'En attente'
            ? AppColors.pending
            : AppColors.inkMuted;
    final amount = (transaction['amount'] as num).toDouble();

    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : AppColors.cardLine,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          AppColors.forestDark,
                          AppColors.forestDarker
                        ]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(transaction['name']),
                      style: AppText.sans(
                          size: 15,
                          weight: FontWeight.bold,
                          color: AppColors.goldLight),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Center(
                      child: Text(transaction['flag'],
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction['name'],
                      style: AppText.sans(
                          size: 15,
                          weight: FontWeight.w700,
                          color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    transaction['country'].toString().isEmpty
                        ? transaction['date']
                        : '${transaction['date']} · ${transaction['country']}',
                    style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'} ${_formatAmount(amount)} $_currency',
                  style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w700,
                      color:
                          isCredit ? AppColors.success : AppColors.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(transaction['status'],
                        style: AppText.sans(
                            size: 12,
                            weight: FontWeight.w600,
                            color: statusColor)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BOTTOM NAV
  // ══════════════════════════════════════════════════════════════

  Widget _buildModernBottomNav() {
    return Container(
      height: 75,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.forestDark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDark.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Accueil', 0),
            _buildNavItem(Icons.swap_horiz_rounded, 'Transfert', 1),
            _buildNavItem(Icons.history_rounded, 'Historique', 2),
            _buildNavItem(Icons.person_rounded, 'Profil', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        if (index == 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        if (index == 1 && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SendMoneyPage()),
          );
          if (mounted) {
            _loadWallet();
            _loadTransactions();
          }
        } else if (index == 2 && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
          if (mounted) {
            _loadWallet();
            _loadTransactions();
          }
        } else if (index == 3 && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
          if (mounted) {
            _loadUserProfile();
            _loadWallet();
            _loadTransactions();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gold.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AppColors.gold : Colors.white54,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.sans(
                size: 11,
                weight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.gold : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QR MODAL
  // ══════════════════════════════════════════════════════════════

  Widget _buildQRModal() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showQRModal = false);
        _qrModalController.reverse();
      },
      child: Container(
        color: AppColors.forestDarker.withOpacity(0.85),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: AnimatedBuilder(
              animation: _qrModalAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _qrModalAnimation.value,
                  child: Opacity(
                    opacity: _qrModalAnimation.value,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('QR Code',
                                  style: AppText.serif(
                                      size: 22,
                                      weight: FontWeight.w600,
                                      color: AppColors.ink)),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _showQRModal = false);
                                  _qrModalController.reverse();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 20, color: AppColors.inkMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _qrModalMode = 0);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _qrModalMode == 0
                                            ? AppColors.forestDark
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text('Mon QR Code',
                                            style: AppText.sans(
                                                size: 14,
                                                weight: FontWeight.w600,
                                                color: _qrModalMode == 0
                                                    ? Colors.white
                                                    : AppColors.inkMuted)),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _qrModalMode = 1);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _qrModalMode == 1
                                            ? AppColors.gold
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text('Scanner',
                                            style: AppText.sans(
                                                size: 14,
                                                weight: FontWeight.w600,
                                                color: _qrModalMode == 1
                                                    ? Colors.white
                                                    : AppColors.inkMuted)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _qrModalMode == 0
                              ? _buildQRModalMyQR()
                              : _buildQRModalScanner(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRModalMyQR() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardLine, width: 1.5),
          ),
          child: QrImageView(
            data: _buildQRPayload(),
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.forestDark,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Scannez ce code pour m\'envoyer de l\'argent',
          style: AppText.sans(
              size: 14, weight: FontWeight.w500, color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        if (_userPhone.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _userPhone,
            style: AppText.sans(
                size: 13, weight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ],
    );
  }

  Widget _buildQRModalScanner() {
    return Column(
      children: [
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    size: 80, color: AppColors.forestDark),
                const SizedBox(height: 16),
                Text('Scanner QR Code',
                    style: AppText.serif(
                        size: 16,
                        weight: FontWeight.w600,
                        color: AppColors.ink)),
                const SizedBox(height: 8),
                Text('Appuyez pour ouvrir le scanner',
                    style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w500,
                        color: AppColors.inkMuted),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _showQRModal = false);
            _qrModalController.reverse();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerPage()),
            ).then((_) {
              if (mounted) {
                _loadWallet();
                _loadTransactions();
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.forestDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text('Ouvrir le Scanner',
                  style: AppText.sans(
                      size: 16,
                      weight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}