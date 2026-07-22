import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';

class ZelixApp extends StatelessWidget {
  const ZelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zelix Rised Trades',
      debugShowCheckedModeBanner: false,

      themeMode: ThemeMode.system,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),

      home: const HomeScreen(),
    );
  }
}
