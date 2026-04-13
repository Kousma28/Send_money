import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'pin_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Activer le mode immersif
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Initialiser le contrôleur vidéo
    _controller = VideoPlayerController.asset('assets/images/ecran.mp4')
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _controller.play();
        
        // NE PAS boucler la vidéo - lecture unique
        _controller.setLooping(false);
        
        // Navigation après la vidéo
        final videoDuration = _controller.value.duration;
        Timer(videoDuration, () async {
          if (mounted) {
            // Vérifier si l'utilisateur a déjà un compte
            final prefs = await SharedPreferences.getInstance();
            final hasAccount = (prefs.containsKey('user_phone') && 
                             prefs.containsKey('user_country_id')) ||
                            (prefs.containsKey('reg_phone') && 
                             prefs.containsKey('reg_country_id'));
            
            if (hasAccount) {
              // Utilisateur existant -> vers page de connexion PIN
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => 
                    const PinLoginScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 800),
                ),
              );
            } else {
              // Nouvel utilisateur -> vers onboarding
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => 
                    const OnboardingScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 800),
                ),
              );
            }
          }
        });
      }).catchError((error) {
        print('Erreur de chargement vidéo: $error');
        // En cas d'erreur, naviguer immédiatement vers onboarding avec transition
        Timer(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  const OnboardingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          }
        });
      });
  }

  @override
  void dispose() {
    // Restaurer le mode UI normal
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isVideoInitialized
          ? Container(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : Container(
              color: Colors.black,
            ),
    );
  }
}

