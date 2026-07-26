import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zelix_rised_trades/ui/screens/menu/main_menu_screen.dart';

class PlayerSetupScreen extends StatefulWidget {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nicknameController = TextEditingController();
  PlayerSetupScreen({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.nicknameController,
  });

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final PageController controller = PageController();
  final empireController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  int page = 0;
  int avatar = 0;
  int difficulty = 1;
  String country = "Japan";

  final avatars = const ["🛡", "⚔", "🏭", "🚚", "🚢", "🚂", "🏰", "👑"];
  final countries = const ["Japan", "USA", "Germany", "Turkey", "England"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkExistingProfile(),
    );
  }

  Future<void> _checkExistingProfile() async {
    if (user == null || !mounted) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (doc.exists && doc.data()?['avatar'] != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    }
  }

  Future<void> startGame() async {
    try {
      debugPrint(
        "Creating user with email: ${widget.emailController.text.trim()}",
      );
      await _auth.createUserWithEmailAndPassword(
        email: widget.emailController.text.trim(),
        password: widget.passwordController.text.trim(),
      );
      await _auth.currentUser!.updateProfile(
        displayName: widget.nicknameController.text.trim(),
      );
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'nickname': user!.displayName ?? '',
        'empireName': empireController.text.trim(),
        'avatar': avatar,
        'country': country,
        'difficulty': difficulty,
        'money': 10000,
        'level': 1,
        'experience': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff07152B),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "CREATE YOUR EMPIRE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  value: (page + 1) / 3,
                  borderRadius: BorderRadius.circular(20),
                  minHeight: 8,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [buildEmpire(), buildCountry(), buildSummary()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEmpire() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: List.generate(avatars.length, (i) {
              return GestureDetector(
                onTap: () => setState(() => avatar = i),
                child: CircleAvatar(
                  radius: avatar == i ? 38 : 32,
                  backgroundColor: avatar == i ? Colors.orange : Colors.white24,
                  child: Text(avatars[i], style: const TextStyle(fontSize: 32)),
                ),
              );
            }),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: empireController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Empire Name",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                setState(() => page = 1);
                controller.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.ease,
                );
              },
              child: const Text(
                "NEXT",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCountry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: country,
            dropdownColor: const Color(0xff0B2E5A),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: "Country",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            items: countries.map((e) {
              return DropdownMenuItem(value: e, child: Text(e));
            }).toList(),
            onChanged: (v) => setState(() => country = v!),
          ),
          const SizedBox(height: 40),
          const Text(
            "Difficulty",
            style: TextStyle(color: Colors.white, fontSize: 22),
          ),
          const SizedBox(height: 20),
          RadioGroup<int>(
            groupValue: difficulty,
            onChanged: (v) => setState(() => difficulty = v!),
            child: Column(
              children: [
                RadioListTile<int>(
                  activeColor: Colors.orange,
                  title: const Text(
                    "Easy",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 0,
                ),
                RadioListTile<int>(
                  activeColor: Colors.orange,
                  title: const Text(
                    "Normal",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 1,
                ),
                RadioListTile<int>(
                  activeColor: Colors.orange,
                  title: const Text(
                    "Hard",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                setState(() => page = 2);
                controller.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.ease,
                );
              },
              child: const Text(
                "NEXT",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Center(
            child: CircleAvatar(
              radius: 50,
              child: Text(
                avatars[avatar],
                style: const TextStyle(fontSize: 45),
              ),
            ),
          ),
          const SizedBox(height: 30),
          ListTile(
            title: const Text(
              "Empire",
              style: TextStyle(color: Colors.white70),
            ),
            subtitle: Text(
              empireController.text,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text(
              "Country",
              style: TextStyle(color: Colors.white70),
            ),
            subtitle: Text(
              country,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          ListTile(
            title: const Text(
              "Difficulty",
              style: TextStyle(color: Colors.white70),
            ),
            subtitle: Text(
              difficulty == 0
                  ? "Easy"
                  : difficulty == 1
                  ? "Normal"
                  : "Hard",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: startGame,
              child: const Text(
                "START GAME",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
