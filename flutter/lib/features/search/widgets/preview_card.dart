import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/search_preview_models.dart';

class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.preview,
    required this.onTap,
  });

  final SearchQuickPreview preview;
  final VoidCallback onTap;

  String _displayPrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '가격 문의';
    if (trimmed.contains('문의') ||
        trimmed.contains('변동') ||
        trimmed.contains('臾몄쓽') ||
        trimmed.contains('蹂')) {
      return '가격 문의';
    }
    return trimmed;
  }

  bool _isFlexiblePrice(String value) {
    return _displayPrice(value) == '가격 문의';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Thumbnail(imageUrl: preview.imageUrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.menuName ?? preview.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (preview.menuName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 11,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              preview.restaurantName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final priceLabel = _displayPrice(preview.priceLabel);
                        return Text(
                          priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _isFlexiblePrice(priceLabel)
                                ? AppColors.textHint
                                : AppColors.success400,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        width: double.infinity,
        height: 110,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _FallbackBox(),
              )
            : const _FallbackBox(),
      ),
    );
  }
}

class _FallbackBox extends StatelessWidget {
  const _FallbackBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0EDE8),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 32,
          color: Color(0xFFCCBBAA),
        ),
      ),
    );
  }
}
