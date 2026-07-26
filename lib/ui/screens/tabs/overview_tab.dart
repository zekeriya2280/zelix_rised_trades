import 'package:flutter/material.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),

      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.people),
            title: Text("Population"),
            trailing: Text("250,000"),
          ),
        ),

        Card(
          child: ListTile(
            leading: Icon(Icons.attach_money),
            title: Text("Income"),
            trailing: Text("¥350,000"),
          ),
        ),

        Card(
          child: ListTile(
            leading: Icon(Icons.factory),
            title: Text("Factories"),
            trailing: Text("14"),
          ),
        ),

        Card(
          child: ListTile(
            leading: Icon(Icons.warehouse),
            title: Text("Warehouse"),
            trailing: Text("85%"),
          ),
        ),
      ],
    );
  }
}
