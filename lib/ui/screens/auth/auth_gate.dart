import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/auth/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthGate - geçici olarak sadece splash screen dönüyor
    // Firebase implementasyonu eklendiğinde güncellenecek
    return const LoginScreen();
  }
}
