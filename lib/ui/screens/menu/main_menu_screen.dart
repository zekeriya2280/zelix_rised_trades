import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/auth/auth_gate.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff06152B), Color(0xff0B2E5A), Color(0xff143E72)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    const Icon(Icons.public, color: Colors.orange, size: 90),

                    const SizedBox(height: 20),

                    const Text(
                      "ZELIX",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Text(
                      "Rise of Trades",
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),

                    const Spacer(),

                    menuButton(context, Icons.play_arrow, "Continue", () {
                      // GameScreen
                    }),

                    const SizedBox(height: 15),

                    menuButton(
                      context,
                      Icons.add_circle_outline,
                      "New Game",
                      () {},
                    ),

                    const SizedBox(height: 15),

                    menuButton(context, Icons.person, "Profile", () {}),

                    const SizedBox(height: 15),

                    menuButton(context, Icons.settings, "Settings", () {}),

                    const SizedBox(height: 15),

                    menuButton(context, Icons.logout, "Logout", logout),

                    const Spacer(),

                    const Text(
                      "Version 1.0.0",
                      style: TextStyle(color: Colors.white38),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget menuButton(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(title, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
