part of 'settings_screen.dart';

class _ReviewButtonsSection extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const _ReviewButtonsSection({this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ReviewNavigationButton(
            icon: Icons.favorite_border,
            iconColor: Color(0xFFE85C5C),
            title: '내 하트',
            subtitle: '하트를 누른 리뷰 목록',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _LikedReviewsSettingsScreen(
                    onSelectTab: onSelectTab,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 0),
          _ReviewNavigationButton(
            icon: Icons.history,
            title: '최근 기록',
            subtitle: '최근 확인한 리뷰 목록',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _RecentReviewsSettingsScreen(
                    onSelectTab: onSelectTab,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewNavigationButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReviewNavigationButton({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
