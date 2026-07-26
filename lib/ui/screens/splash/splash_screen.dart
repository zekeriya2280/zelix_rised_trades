import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // AuthGate yerine doğrudan ana ekrana gidiyoruz
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff071330), Color(0xff132b59)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.public, size: 90, color: Colors.white),

              SizedBox(height: 20),

              Text(
                "ZELIX",
                style: TextStyle(
                  fontSize: 34,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8),

              Text("Rise of Trades", style: TextStyle(color: Colors.white70)),

              SizedBox(height: 50),

              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
