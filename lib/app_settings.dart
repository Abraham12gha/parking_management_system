import 'package:flutter/material.dart';

class AppSettings extends StatelessWidget {
  final Function(bool) onThemeChanged;

  const AppSettings({
    super.key,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Settings",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 30,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                onThemeChanged(true);
              },
              child: const Text("Dark Mode"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                onThemeChanged(false);
              },
              child: const Text("Light Mode"),
            ),
          ],
        ),
      ),
    );
  }
}