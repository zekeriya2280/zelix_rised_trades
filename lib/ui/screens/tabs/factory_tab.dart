import 'package:flutter/material.dart';

class FactoryTab extends StatelessWidget {
  const FactoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (_, index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.factory),
            title: Text("Factory ${index + 1}"),
            subtitle: const Text("Producing Furniture"),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
