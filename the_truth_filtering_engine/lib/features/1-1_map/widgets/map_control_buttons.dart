import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MapControlButtons extends StatelessWidget {
  final VoidCallback? onLocationTap;
  final VoidCallback? onLayerTap;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final bool isLayerToggled;

  const MapControlButtons({
    super.key,
    this.onLocationTap,
    this.onLayerTap,
    this.onZoomIn,
    this.onZoomOut,
    this.isLayerToggled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          icon: Icons.my_location,
          tooltip: '내 위치',
          onTap: onLocationTap,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: isLayerToggled ? Icons.layers : Icons.layers_outlined,
          tooltip: '지도 전환',
          onTap: onLayerTap,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.add,
          tooltip: '확대',
          onTap: onZoomIn,
        ),
        const SizedBox(height: 8),
        _ControlButton(
          icon: Icons.remove,
          tooltip: '축소',
          onTap: onZoomOut,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
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
        ),
      ),
    );
  }
}
