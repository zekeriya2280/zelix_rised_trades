import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nicknameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool hidePassword = true;
  bool hideConfirm = true;
  bool loading = false;

  Future<void> register() async {
    if (nicknameController.text.trim().isEmpty) {
      return showMessage("Please enter a nickname.");
    }

    if (emailController.text.trim().isEmpty) {
      return showMessage("Please enter your email.");
    }

    if (passwordController.text.length < 6) {
      return showMessage("Password must be at least 6 characters.");
    }

    if (passwordController.text != confirmController.text) {
      return showMessage("Passwords do not match.");
    }

    setState(() {
      loading = true;
    });

    try {
      // FirebaseAuth.createUserWithEmailAndPassword()

      // Firestore'a nickname kaydedilecek.

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      showMessage(e.toString());
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff06152B), Color(0xff0B2E5A), Color(0xff143E72)],

            begin: Alignment.topCenter,

            end: Alignment.bottomCenter,
          ),
        ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),

                padding: const EdgeInsets.all(28),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),

                  borderRadius: BorderRadius.circular(24),

                  border: Border.all(color: Colors.white24),
                ),

                child: Column(
                  children: [
                    const Icon(
                      Icons.account_circle,

                      color: Colors.orange,

                      size: 80,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "CREATE ACCOUNT",

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 30,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Build your trading empire.",

                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 35),

                    TextField(
                      controller: nicknameController,

                      style: const TextStyle(color: Colors.white),

                      decoration: input("Nickname", Icons.person),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: emailController,

                      style: const TextStyle(color: Colors.white),

                      decoration: input("Email", Icons.email),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: passwordController,

                      obscureText: hidePassword,

                      style: const TextStyle(color: Colors.white),

                      decoration: input("Password", Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),

                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: confirmController,

                      obscureText: hideConfirm,

                      style: const TextStyle(color: Colors.white),

                      decoration: input("Confirm Password", Icons.lock_outline)
                          .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                hideConfirm
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),

                              onPressed: () {
                                setState(() {
                                  hideConfirm = !hideConfirm;
                                });
                              },
                            ),
                          ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,

                      height: 56,

                      child: ElevatedButton(
                        onPressed: loading ? null : register,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "CREATE ACCOUNT",

                                style: TextStyle(
                                  fontWeight: FontWeight.bold,

                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },

                      child: const Text(
                        "Already have an account? Login",

                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration input(String title, IconData icon) {
    return InputDecoration(
      labelText: title,

      labelStyle: const TextStyle(color: Colors.white70),

      prefixIcon: Icon(icon, color: Colors.orange),

      filled: true,

      fillColor: Colors.white10,

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
