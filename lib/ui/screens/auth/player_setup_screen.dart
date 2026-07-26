import 'package:flutter/material.dart';

class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final PageController controller = PageController();

  final empireController = TextEditingController();

  int page = 0;

  int avatar = 0;

  int difficulty = 1;

  String country = "Japan";

  final avatars = const ["🛡", "⚔", "🏭", "🚚", "🚢", "🚂", "🏰", "👑"];

  final countries = const ["Japan", "USA", "Germany", "Turkey", "England"];

  Future<void> startGame() async {
    /// TODO

    /*
      Firebase Save Player

      GameInitializer.createWorld()

      Navigator.pushReplacement(
          MainMenuScreen()
      );

    */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff07152B),

      body: SafeArea(
        child: Column(
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
    );
  }

  Widget buildEmpire() {
    return Padding(
      padding: const EdgeInsets.all(24),

      child: Column(
        children: [
          const SizedBox(height: 30),

          Wrap(
            spacing: 15,

            runSpacing: 15,

            children: List.generate(avatars.length, (i) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    avatar = i;
                  });
                },

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

          const Spacer(),

          SizedBox(
            width: double.infinity,

            height: 55,

            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  page = 1;
                });

                controller.nextPage(
                  duration: const Duration(milliseconds: 400),

                  curve: Curves.ease,
                );
              },

              child: const Text("NEXT"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCountry() {
    return Padding(
      padding: const EdgeInsets.all(24),

      child: Column(
        children: [
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            initialValue: country,
            dropdownColor: Colors.blueGrey,
            items: countries.map((e) {
              return DropdownMenuItem(value: e, child: Text(e));
            }).toList(),

            onChanged: (v) {
              setState(() {
                country = v!;
              });
            },
          ),

          const SizedBox(height: 40),

          const Text(
            "Difficulty",

            style: TextStyle(color: Colors.white, fontSize: 22),
          ),

          const SizedBox(height: 20),

          RadioGroup<int>(
            groupValue: difficulty,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  difficulty = value;
                });
              }
            },
            child: Radio<int>(
              value: 0,
              side: BorderSide(color: Colors.white, width: 3),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,

            height: 55,

            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  page = 2;
                });

                controller.nextPage(
                  duration: const Duration(milliseconds: 400),

                  curve: Curves.ease,
                );
              },

              child: const Text("NEXT"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(24),

      child: Column(
        children: [
          const SizedBox(height: 30),

          CircleAvatar(
            radius: 50,

            child: Text(avatars[avatar], style: const TextStyle(fontSize: 45)),
          ),

          const SizedBox(height: 30),

          ListTile(
            title: const Text("Empire"),

            subtitle: Text(empireController.text),
          ),

          ListTile(title: const Text("Country"), subtitle: Text(country)),

          ListTile(
            title: const Text("Difficulty"),

            subtitle: Text(
              difficulty == 0
                  ? "Easy"
                  : difficulty == 1
                  ? "Normal"
                  : "Hard",
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,

            height: 60,

            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),

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
