import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home_screen.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Transfert reçu',
      'message': 'Vous avez reçu 50,000 FCFA de Marie Dubois',
      'time': 'Il y a 2 min',
      'type': 'transaction',
      'isRead': false,
      'icon': Icons.arrow_downward,
      'color': Colors.green,
    },
    {
      'id': 2,
      'title': 'Offre spéciale',
      'message': '10% de cashback sur tous vos transferts cette semaine',
      'time': 'Il y a 1h',
      'type': 'promo',
      'isRead': false,
      'icon': Icons.local_offer,
      'color': Colors.orange,
    },
    {
      'id': 3,
      'title': 'Transfert envoyé',
      'message': 'Votre transfert de 25,000 FCFA vers Jean Martin a été effectué',
      'time': 'Il y a 3h',
      'type': 'transaction',
      'isRead': true,
      'icon': Icons.arrow_upward,
      'color': Colors.blue,
    },
    {
      'id': 4,
      'title': 'Mise à jour sécurité',
      'message': 'Votre application a été mise à jour avec les dernières mesures de sécurité',
      'time': 'Il y a 5h',
      'type': 'system',
      'isRead': true,
      'icon': Icons.security,
      'color': Colors.purple,
    },
    {
      'id': 5,
      'title': 'Solde faible',
      'message': 'Votre solde est inférieur à 10,000 FCFA',
      'time': 'Hier',
      'type': 'alert',
      'isRead': true,
      'icon': Icons.warning,
      'color': Colors.red,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF6366F1)),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNotifications,
        child: Column(
          children: [
            // Header avec compteur
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_notifications.where((n) => !n['isRead']).length} notifications non lues',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAllNotifications,
                    child: const Text(
                      'Tout effacer',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Liste des notifications
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(0),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return Dismissible(
                    key: Key(notification['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteNotification(notification['id'], notification['title']);
                    },
                    child: _buildNotificationItem(notification),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _markAsRead(notification['id']);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification['isRead'] ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification['isRead'] 
                ? const Color(0xFFE5E7EB) 
                : const Color(0xFF6366F1).withOpacity(0.2),
            width: notification['isRead'] ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icône de notification
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (notification['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                notification['icon'],
                color: notification['color'] as Color,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Contenu de la notification
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'],
                          style: TextStyle(
                            color: const Color(0xFF1F2937),
                            fontSize: 16,
                            fontWeight: notification['isRead'] 
                                ? FontWeight.w500 
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!notification['isRead'])
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['message'],
                    style: TextStyle(
                      color: const Color(0xFF6B7280),
                      fontSize: 14,
                      fontWeight: notification['isRead'] 
                          ? FontWeight.w400 
                          : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification['time'],
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            _buildNavItem(Icons.person_rounded, 'Profil', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF9CA3AF),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNotification(int notificationId, String notificationTitle) {
    HapticFeedback.mediumImpact();
    setState(() {
      _notifications.removeWhere((notification) => notification['id'] == notificationId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$notificationTitle" a été supprimée'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            // Optionnel: restaurer la notification
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  void _markAsRead(int notificationId) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n['id'] == notificationId);
      notification['isRead'] = true;
    });
  }

  void _markAllAsRead() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les notifications ont été marquées comme lues'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearAllNotifications() {
    HapticFeedback.mediumImpact();
    setState(() {
      _notifications.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les notifications ont été effacées'),
        backgroundColor: Color(0xFFEF4444),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _refreshNotifications() async {
    await Future.delayed(const Duration(seconds: 1));
    HapticFeedback.lightImpact();
    // Simuler le rafraîchissement des notifications
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications actualisées'),
        backgroundColor: Color(0xFF6366F1),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
