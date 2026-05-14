import 'package:flutter/material.dart';

import '../../../models/search_preview_models.dart';

class IssueChipRow extends StatelessWidget {
  const IssueChipRow({
    super.key,
    required this.chips,
    required this.onChipTapped,
  });

  final List<SearchIssueChip> chips;
  final ValueChanged<SearchIssueChip> onChipTapped;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final chip = chips[index];
          return _IssueChip(
            chip: chip,
            onTap: () => onChipTapped(chip),
          );
        },
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({
    required this.chip,
    required this.onTap,
  });

  final SearchIssueChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F0FF),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD4C5FF),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: Color(0xFF6B4FBB),
              ),
              const SizedBox(width: 5),
              Text(
                chip.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B4FBB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
