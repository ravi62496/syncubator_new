import 'package:flutter/material.dart';

class RaspberryScreen extends StatelessWidget {
  const RaspberryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Raspberry Pi",
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}