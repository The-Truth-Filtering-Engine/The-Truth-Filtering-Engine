import 'package:flutter/material.dart';

class AppBarLogo extends StatelessWidget {
  const AppBarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.verified, size: 20),
        SizedBox(width: 6),
        Text("진실의 입"),
      ],
    );
  }
}