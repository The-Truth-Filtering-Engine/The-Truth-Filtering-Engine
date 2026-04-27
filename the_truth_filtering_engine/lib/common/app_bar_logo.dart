import 'package:flutter/material.dart';

class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/logo.png',
          width: 32,
          height: 32,
        ),
        const SizedBox(width: 6),
        const Text("진실의 입"),
      ],
    );
  }
}
