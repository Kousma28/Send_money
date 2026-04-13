import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔧 Changez cette URL par l'adresse de votre serveur Laravel
  static const String baseUrl = 'http://192.168.1.3:8000/api';

  // ─── Headers ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> get _authHeaders async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, ...body};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Une erreur est survenue.',
        ...body,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Réponse invalide du serveur.',
      };
    }
  }

  // ─── Pays ────────────────────────────────────────────────────────────────────

  /// GET /api/countries
  /// Retourne la liste des pays depuis le back-end.
  Future<Map<String, dynamic>> getCountries() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/countries'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur. Vérifiez votre connexion.'};
    }
  }

  // ─── Inscription ─────────────────────────────────────────────────────────────

  /// ÉTAPE 1 — POST /api/register/phone
  /// Enregistre le numéro de téléphone et le pays.
  /// Retourne { success, data: { user_id, phone, country_code } }
  Future<Map<String, dynamic>> registerPhone({
    required String phone,
    required int countryId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/phone'),
            headers: _headers,
            body: jsonEncode({'phone': phone, 'country_id': countryId}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// ÉTAPE 2 — POST /api/register/profile
  /// Enregistre le prénom et le nom de l'utilisateur.
  /// Retourne { success, data: UserResource }
  Future<Map<String, dynamic>> registerProfile({
    required int userId,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/profile'),
            headers: _headers,
            body: jsonEncode({
              'user_id':    userId,
              'first_name': firstName,
              'last_name':  lastName,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// ÉTAPE 3 — POST /api/register/pin
  /// Enregistre temporairement le code PIN.
  /// Retourne { success, message }
  Future<Map<String, dynamic>> registerPin({
    required int userId,
    required String pin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/pin'),
            headers: _headers,
            body: jsonEncode({'user_id': userId, 'pin': pin}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// ÉTAPE 4 — POST /api/register/confirm-pin
  /// Confirme le PIN et finalise la création du compte.
  /// Retourne { success, data: { user, token, token_type } }
  Future<Map<String, dynamic>> confirmPin({
    required int userId,
    required String pin,
    required String pinConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/confirm-pin'),
            headers: _headers,
            body: jsonEncode({
              'user_id':          userId,
              'pin':              pin,
              'pin_confirmation': pinConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final result = _handleResponse(response);

      // Sauvegarder le token si l'inscription est réussie
      if (result['success'] == true) {
        final token = result['data']?['token'] as String?;
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          
          // Envoyer le message de bienvenue
          await sendWelcomeMessage();
        }
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  // ─── Authentification ────────────────────────────────────────────────────────

  /// POST /api/login
  /// Connexion par téléphone + pays + PIN.
  /// Retourne { success, data: { user, token, token_type } }
  Future<Map<String, dynamic>> login({
    required String phone,
    required int countryId,
    required String pin,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: _headers,
            body: jsonEncode({
              'phone':      phone,
              'country_id': countryId,
              'pin':        pin,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final result = _handleResponse(response);

      if (result['success'] == true) {
        final token = result['data']?['token'] as String?;
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
        }
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// GET /api/me  (token requis)
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// POST /api/logout  (token requis)
  Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      print('Token pour déconnexion: ${token.isNotEmpty ? 'présent' : 'vide/absent'}');
      
      if (token.isEmpty) {
        // Si pas de token, on considère la déconnexion comme réussie localement
        await prefs.remove('auth_token');
        return {'success': true, 'message': 'Déconnexion réussie.'};
      }
      
      final response = await http
          .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      final result = _handleResponse(response);

      // Supprimer le token local dans tous les cas
      await prefs.remove('auth_token');

      return result;
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      
      // En cas d'erreur réseau, on supprime le token localement quand même
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      return {'success': true, 'message': 'Déconnexion réussie (locale).'};
    }
  }

  // --------------------------------------------------------
  // Taux de change (public) ---------------------------------

  /// GET /api/exchange-rates
  /// Retourne tous les corridors actifs avec taux et frais.
  Future<Map<String, dynamic>> getExchangeRates() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/exchange-rates'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de charger les taux.'};
    }
  }

  // --------------------------------------------------------
  // Simulation avant envoi ----------------------------------

  /// POST /api/transfers/simulate  (token requis)
  /// Calcule les frais et le montant converti sans ecrire en base.
  /// Retourne {
  ///   amount_sent, currency_sent,
  ///   fee_amount, fee_percent,
  ///   total_deducted,
  ///   amount_received, currency_received,
  ///   exchange_rate
  /// }
  Future<Map<String, dynamic>> simulateTransfer({
    required int toCountryId,
    required double amount,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfers/simulate'),
            headers: await _authHeaders,
            body: jsonEncode({'to_country_id': toCountryId, 'amount': amount}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de calculer les frais.'};
    }
  }

  // --------------------------------------------------------
  // Envoi d'argent ------------------------------------------

  /// POST /api/transfers  (token requis)
  /// Effectue le transfert et retourne la reference + montants.
  Future<Map<String, dynamic>> sendTransfer({
    required String receiverPhone,
    required int    toCountryId,
    required double amount,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/transfers'),
            headers: await _authHeaders,
            body: jsonEncode({
              'receiver_phone': receiverPhone,
              'to_country_id':  toCountryId,
              'amount':         amount,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  // --------------------------------------------------------
  // Historique des transferts --------------------------------

  /// GET /api/transfers?page=1  (token requis)
  Future<Map<String, dynamic>> getTransfers({int page = 1}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/transfers?page=$page'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de charger l\'historique.'};
    }
  }

  // --------------------------------------------------------
  // Wallet --------------------------------------------------

  /// GET /api/wallet  (token requis)
  Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/wallet'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de charger le solde.'};
    }
  }

  /// POST /api/wallet/topup  (token requis)
  /// En prod, cet appel vient de votre passerelle de paiement.
  Future<Map<String, dynamic>> topupWallet({
    required double amount,
    String description = 'Recharge',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/wallet/topup'),
            headers: await _authHeaders,
            body: jsonEncode({'amount': amount, 'description': description}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de joindre le serveur.'};
    }
  }

  /// GET /api/wallet/transactions  (token requis)
  Future<Map<String, dynamic>> getWalletTransactions({int page = 1}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/wallet/transactions?page=$page'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible de charger les transactions.'};
    }
  }

  // --------------------------------------------------------
  // Messages ------------------------------------------------
  
  /// POST /api/send-welcome  (token requis)
  /// Envoie un message de bienvenue à l'utilisateur
  Future<Map<String, dynamic>> sendWelcomeMessage() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/send-welcome'),
            headers: await _authHeaders,
            body: jsonEncode({
              'message': 'Bienvenue sur Paylio ! Merci d\'avoir choisi notre application pour vos transferts d\'argent. Nous sommes ravis de vous compter parmi nos utilisateurs.',
              'type': 'welcome'
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Impossible d\'envoyer le message de bienvenue.'};
    }
  }

}