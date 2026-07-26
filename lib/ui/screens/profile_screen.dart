import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff07152B),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Commander Profile"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.orange,
              child: Text("👑", style: TextStyle(fontSize: 50)),
            ),

            const SizedBox(height: 15),

            const Text(
              "Zek Logistics",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Level 5 Commander",
              style: TextStyle(color: Colors.white60),
            ),

            const SizedBox(height: 30),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.6,
              children: const [
                StatCard(
                  icon: Icons.account_balance_wallet,
                  title: "Money",
                  value: "¥125,000",
                ),

                StatCard(icon: Icons.factory, title: "Factories", value: "12"),

                StatCard(
                  icon: Icons.warehouse,
                  title: "Warehouses",
                  value: "4",
                ),

                StatCard(
                  icon: Icons.local_shipping,
                  title: "Trucks",
                  value: "18",
                ),

                StatCard(
                  icon: Icons.location_city,
                  title: "Cities",
                  value: "3",
                ),

                StatCard(icon: Icons.bar_chart, title: "Level", value: "5"),
              ],
            ),

            const SizedBox(height: 30),

            Card(
              color: Colors.white10,

              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text("Edit Profile"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.flag),
                    title: const Text("Change Country"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Logout"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Achievements",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                Chip(
                  avatar: Icon(Icons.emoji_events),
                  label: Text("First Factory"),
                ),

                Chip(avatar: Icon(Icons.emoji_events), label: Text("Trader")),

                Chip(
                  avatar: Icon(Icons.emoji_events),
                  label: Text("Millionaire"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white10,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, size: 34, color: Colors.orange),

            const SizedBox(height: 10),

            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(title, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
