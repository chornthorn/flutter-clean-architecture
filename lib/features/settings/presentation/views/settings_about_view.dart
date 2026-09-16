import 'package:flutter/material.dart';

// Pushed inside the feature.
class SettingsAboutView extends StatelessWidget {
  const SettingsAboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Center(child: Text('About this app')),
    );
  }
}
