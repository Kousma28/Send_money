import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../home_screen.dart';
import 'send_money_page.dart';
import 'history_page.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  late AnimationController _profileController;
  late AnimationController _sectionsController;
  late Animation<double> _profileAnimation;
  late List<Animation<double>> _sectionAnimations;
  
  // Variables pour le profil utilisateur
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  String _userName = 'Chargement...';
  String _userPhone = 'Chargement...';
  String _userEmail = 'Chargement...';
  String _profileImagePath = '';
  bool _isLoadingProfile = true;
  
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'Français';
  String _selectedCurrency = 'FCFA';

  void _toggleDarkMode(bool value) {
    setState(() {
      _darkModeEnabled = value;
    });
    
    // Appliquer le thème à l'application
    // Note: Pour une vraie implémentation, vous devriez utiliser Theme.of(context).changeTheme
    // ou un gestionnaire d'état comme Provider ou Bloc
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Mode sombre activé' : 'Mode clair activé'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _profileController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _sectionsController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _profileAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _profileController,
      curve: Curves.easeOutQuart,
    ));
    
    _sectionAnimations = List.generate(
      4,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _sectionsController,
          curve: Interval(
            index * 0.15,
            0.4 + (index * 0.15),
            curve: Curves.easeOutQuart,
          ),
        ),
      ),
    );
    
    _profileController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _sectionsController.forward();
    });
    
    // Charger le profil utilisateur
    _loadUserProfile();
  }

  // Charger le profil utilisateur depuis l'API
  Future<void> _loadUserProfile() async {
    try {
      final result = await _apiService.getMe();
      
      if (!mounted) return;
      
      if (result['success'] == true && result['data'] != null) {
        final userData = result['data'] as Map<String, dynamic>;
        final firstName = userData['first_name'] as String? ?? '';
        final lastName = userData['last_name'] as String? ?? '';
        final phone = userData['phone'] as String? ?? '';
        final email = userData['email'] as String? ?? '';
        final profileImage = userData['profile_image'] as String? ?? '';
        
        setState(() {
          _userName = '$firstName $lastName'.trim();
          _userPhone = phone;
          _userEmail = email;
          _profileImagePath = profileImage;
          _isLoadingProfile = false;
        });
      } else {
        // En cas d'erreur, essayer de récupérer depuis SharedPreferences
        await _loadProfileFromCache();
      }
    } catch (e) {
      // En cas d'erreur de connexion, essayer le cache
      await _loadProfileFromCache();
    }
  }

  // Charger le profil depuis le cache (SharedPreferences)
  Future<void> _loadProfileFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('temp_first_name') ?? '';
      final lastName = prefs.getString('temp_last_name') ?? '';
      final phone = prefs.getString('temp_phone') ?? '';
      final profileImage = prefs.getString('profile_image') ?? '';
      
      if (!mounted) return;
      
      setState(() {
        _userName = '$firstName $lastName'.trim();
        _userPhone = phone;
        _userEmail = ''; // Pas d'email dans le cache
        _profileImagePath = profileImage;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userName = 'Utilisateur';
        _userPhone = '';
        _userEmail = '';
        _profileImagePath = '';
        _isLoadingProfile = false;
      });
    }
  }

  // Afficher le bottom sheet pour choisir la source de l'image
  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Photo de profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Caméra',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compresser une image pour réduire sa taille (méthode ultra-simplifiée)
  Future<File?> _compressImage(String imagePath) async {
    try {
      // Pour l'instant, on retourne simplement le fichier original
      // La compression sera faite plus tard avec une meilleure approche
      print('Utilisation du fichier original sans compression temporairement');
      return File(imagePath);
    } catch (e) {
      print('Erreur lors de la compression: $e');
      return null;
    }
  }

  // Prendre une photo avec la caméra
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Qualité réduite pour les profils
        maxWidth: 600,     // Taille modérée
        maxHeight: 600,
      );
      
      if (image != null && mounted) {
        await _saveProfileImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la capture de la photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Choisir une image depuis la galerie
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Qualité réduite pour les profils
        maxWidth: 600,     // Taille modérée
        maxHeight: 600,
      );
      
      if (image != null && mounted) {
        await _saveProfileImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Sauvegarder l'image de profil
  Future<void> _saveProfileImage(String imagePath) async {
    try {
      print('Sauvegarde de l\'image: $imagePath');
      
      // Vérifier que le fichier existe
      final file = File(imagePath);
      if (!await file.exists()) {
        print('Erreur: Le fichier n\'existe pas');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fichier image introuvable'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Sauvegarder dans SharedPreferences pour le cache local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', imagePath);
      
      print('Image sauvegardée dans SharedPreferences');
      
      setState(() {
        _profileImagePath = imagePath;
      });
      
      // TODO: Envoyer l'image au backend pour la sauvegarder
      // Pour l'instant, on la sauvegarde juste localement
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de l\'image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _profileController.dispose();
    _sectionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildProfileCard(),
            const SizedBox(height: 32),
            _buildSettingsSections(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _profileAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-50 * (1 - _profileAnimation.value), 0),
          child: Opacity(
            opacity: _profileAnimation.value,
            child: const Text(
              'Paramètres',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard() {
    return AnimatedBuilder(
      animation: _profileAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _profileAnimation.value)),
          child: Opacity(
            opacity: _profileAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar cliquable pour changer la photo
                  GestureDetector(
                    onTap: _showImagePickerBottomSheet,
                    child: Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Image de profil ou initiales
                            Center(
                              child: _isLoadingProfile
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : _profileImagePath.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: _profileImagePath.startsWith('assets/') 
                                              ? Image.asset(
                                                  _profileImagePath,
                                                  width: 76,
                                                  height: 76,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return _buildDefaultAvatar();
                                                  },
                                                )
                                              : Image.file(
                                                  File(_profileImagePath),
                                                  width: 76,
                                                  height: 76,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return _buildDefaultAvatar();
                                                  },
                                                )
                                        )
                                      : _buildDefaultAvatar(),
                            ),
                            // Icône de caméra pour indiquer que c'est cliquable
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF6366F1),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _isLoadingProfile
                            ? Container(
                                width: 150,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : Text(
                                _userName.isNotEmpty ? _userName : 'Utilisateur',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        const SizedBox(height: 4),
                        _isLoadingProfile
                            ? Container(
                                width: 120,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : Text(
                                _userPhone.isNotEmpty ? _userPhone : 'Non disponible',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Compte Vérifié',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar() {
    final initials = _getInitials(_userName);
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Méthode pour générer les initiales
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1 && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  Widget _buildSettingsSections() {
    return Column(
      children: [
        _buildAnimatedSection(0, 'Profil', [
          _buildSettingsTile(
            'Informations personnelles',
            Icons.person_outline,
            () => _showProfileDialog(),
          ),
          _buildSettingsTile(
            'Photo de profil',
            Icons.camera_alt_outlined,
            () => _showPhotoDialog(),
          ),
          _buildSettingsTile(
            'Statut du compte',
            Icons.verified_user_outlined,
            () => _showAccountStatusDialog(),
          ),
        ]),
        const SizedBox(height: 24),
        _buildAnimatedSection(1, 'Sécurité', [
          _buildSettingsTile(
            'Mot de passe',
            Icons.lock_outline,
            () => _showPasswordDialog(),
          ),
          _buildSettingsTile(
            'Authentification biométrique',
            Icons.fingerprint,
            () {},
            isToggle: true,
            toggleValue: _biometricEnabled,
            onToggle: (value) => setState(() => _biometricEnabled = value),
          ),
          _buildSettingsTile(
            'Appareils connectés',
            Icons.devices_outlined,
            () => _showDevicesDialog(),
          ),
        ]),
        const SizedBox(height: 24),
        _buildAnimatedSection(2, 'Préférences', [
          _buildSettingsTile(
            'Notifications',
            Icons.notifications_outlined,
            () {},
            isToggle: true,
            toggleValue: _notificationsEnabled,
            onToggle: (value) => setState(() => _notificationsEnabled = value),
          ),
          _buildSettingsTile(
            'Langue',
            Icons.language,
            () => _showLanguageDialog(),
            subtitle: _selectedLanguage,
          ),
          _buildSettingsTile(
            'Devise',
            Icons.attach_money,
            () => _showCurrencyDialog(),
            subtitle: _selectedCurrency,
          ),
          _buildSettingsTile(
            'Mode sombre',
            Icons.dark_mode_outlined,
            () {},
            isToggle: true,
            toggleValue: _darkModeEnabled,
            onToggle: _toggleDarkMode,
          ),
        ]),
        const SizedBox(height: 24),
        _buildAnimatedSection(3, 'Support', [
          _buildSettingsTile(
            'Centre d\'aide',
            Icons.help_outline,
            () => _showHelpDialog(),
          ),
          _buildSettingsTile(
            'Contactez-nous',
            Icons.contact_support_outlined,
            () => _showContactDialog(),
          ),
          _buildSettingsTile(
            'À propos',
            Icons.info_outline,
            () => _showAboutDialog(),
          ),
          _buildSettingsTile(
            'Déconnexion',
            Icons.logout,
            () => _showLogoutDialog(),
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  Widget _buildAnimatedSection(int index, String title, List<Widget> tiles) {
    return AnimatedBuilder(
      animation: _sectionAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - _sectionAnimations[index].value)),
          child: Opacity(
            opacity: _sectionAnimations[index].value,
            child: _buildSettingsSection(title, tiles),
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          ...tiles,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? subtitle,
    bool isToggle = false,
    bool toggleValue = false,
    Function(bool)? onToggle,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isToggle ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withValues(alpha: 0.1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDestructive ? Colors.red : const Color(0xFF1F2937),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (isToggle)
                Switch(
                  value: toggleValue,
                  onChanged: onToggle,
                  activeColor: const Color(0xFF6366F1),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informations personnelles'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showPhotoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo de profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _showAccountStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statut du compte'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user,
              color: Colors.green,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Votre compte est vérifié',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Vous pouvez effectuer des transferts jusqu\'à 10,000,000 FCFA par jour.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
  }

  void _showDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appareils connectés'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDeviceTile('iPhone 13 Pro', 'Actif maintenant', 'iOS 16.0'),
            const SizedBox(height: 12),
            _buildDeviceTile('MacBook Pro', 'Il y a 2 heures', 'macOS 13.0'),
            const SizedBox(height: 12),
            _buildDeviceTile('iPad Air', 'Il y a 3 jours', 'iPadOS 16.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(String name, String lastActive, String os) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$lastActive • $os',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['Français', 'English', 'Español', 'Português'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) {
            return RadioListTile<String>(
              title: Text(language),
              value: language,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
                Navigator.of(context).pop();
              },
              activeColor: const Color(0xFF6366F1),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['FCFA', 'EUR', 'USD', 'GBP'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Devise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((currency) {
            return RadioListTile<String>(
              title: Text(currency),
              value: currency,
              groupValue: _selectedCurrency,
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value!;
                });
                Navigator.of(context).pop();
              },
              activeColor: const Color(0xFF6366F1),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Centre d\'aide'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.article),
              title: Text('Guide d\'utilisation'),
            ),
            ListTile(
              leading: Icon(Icons.question_answer),
              title: Text('FAQ'),
            ),
            ListTile(
              leading: Icon(Icons.video_library),
              title: Text('Tutoriels vidéo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contactez-nous'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              subtitle: Text('support@sendmoney.com'),
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Téléphone'),
              subtitle: Text('+242 06 123 456'),
            ),
            ListTile(
              leading: Icon(Icons.chat),
              title: Text('Chat en direct'),
              subtitle: Text('Disponible 24/7'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Send Money',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.send, size: 48),
      children: const [
        Text('Application de transfert d\'argent rapide et sécurisée'),
        SizedBox(height: 16),
        Text('© 2024 Send Money. Tous droits réservés.'),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Afficher un indicateur de chargement
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('Déconnexion...'),
                    ],
                  ),
                ),
              );
              
              // Appeler l'API de déconnexion
              final apiService = ApiService();
              final result = await apiService.logout();
              
              // Fermer le dialogue de chargement
              Navigator.of(context).pop();
              
              // Afficher un message de succès ou d'erreur
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Déconnexion réussie.'),
                    backgroundColor: result['success'] == true ? Colors.green : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
                
                // Rediriger vers la page de connexion PIN après un court délai
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/pin-login', (route) => false);
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, -8),
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
            _buildNavItem(Icons.person_rounded, 'Profil', 3, isActive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {bool isActive = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SendMoneyPage()),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF6366F1).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFF9CA3AF),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
