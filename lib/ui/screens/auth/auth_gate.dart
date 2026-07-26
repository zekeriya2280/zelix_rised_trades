import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/auth/login_screen.dart';
import 'package:zelix_rised_trades/ui/screens/auth/player_setup_screen.dart';
import 'package:zelix_rised_trades/ui/screens/menu/main_menu_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const MainMenuScreen();
        return const LoginScreen();
      },
    );
  }
}
