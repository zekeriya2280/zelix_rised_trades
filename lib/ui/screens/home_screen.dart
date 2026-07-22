import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zelix Rised Trades'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FlutterLogo(size: 100),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: () {
                    // Yeni oyun
                  },
                  child: const Text('New Game'),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: () {
                    // Oyuna devam
                  },
                  child: const Text('Continue'),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: () {
                    // Ayarlar
                  },
                  child: const Text('Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
