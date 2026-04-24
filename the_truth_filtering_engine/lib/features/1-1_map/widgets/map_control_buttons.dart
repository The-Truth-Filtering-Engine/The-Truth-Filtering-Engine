import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MapControlButtons extends StatelessWidget {
  final VoidCallback? onLocationTap;
  final VoidCallback? onLayerTap;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const MapControlButtons({
    super.key,
    this.onLocationTap,
    this.onLayerTap,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(icon: Icons.my_location, onTap: onLocationTap),
        const SizedBox(height: 8),
        _ControlButton(icon: Icons.layers_outlined, onTap: onLayerTap),
        const SizedBox(height: 8),
        _ControlButton(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 8),
        _ControlButton(icon: Icons.remove, onTap: onZoomOut),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.controlButtonBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppColors.controlButtonIcon,
          size: 22,
        ),
      ),
    );
  }
}
