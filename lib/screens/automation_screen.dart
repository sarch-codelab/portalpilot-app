import 'package:flutter/material.dart';

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Automation Studio\n\nPróximamente',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          color: Colors.white54,
          fontFamily: 'sans-serif',
        ),
      ),
    );
  }
}
