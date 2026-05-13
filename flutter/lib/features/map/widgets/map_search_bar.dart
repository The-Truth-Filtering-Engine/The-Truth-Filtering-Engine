import 'package:flutter/material.dart';

import '../../../core/design_system/widgets/widgets.dart';

class MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hintText;

  const MapSearchBar({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.hintText = '음식점 또는 메뉴를 검색',
  });

  @override
  Widget build(BuildContext context) {
    return DsTextField(
      controller: controller,
      hintText: hintText,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      onTap: onTap,
      leadingIcon: const Icon(Icons.search, size: 22),
    );
  }
}
