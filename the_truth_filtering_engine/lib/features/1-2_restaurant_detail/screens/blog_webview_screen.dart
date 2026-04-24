import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../1-2.restaurant_detail/models/blog_review.dart';
import '../../../core/theme/app_theme.dart';
import '../../map/widgets/common_widgets.dart';

class BlogWebviewScreen extends StatelessWidget {
  final BlogReview blog;
  const BlogWebviewScreen({super.key, required this.blog});

  bool get _showWarning =>
      blog.status == ReviewStatus.ad || blog.status == ReviewStatus.suspicious;

  Color get _progColor {
    if (blog.adProbability > 60) return AppColors.danger400;
    if (blog.adProbability > 30) return AppColors.warning400;
    return AppColors.success400;
  }

  Color get _progTextColor {
    if (blog.adProbability > 60) return AppColors.danger700;
    if (blog.adProbability > 30) return AppColors.warning700;
    return AppColors.success700;
  }

  Future<void> _openOriginal() async {
    final uri = Uri.parse(blog.url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarLogo(),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── URL 바 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    blog.status == ReviewStatus.ad
                        ? Icons.gpp_bad_outlined
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: blog.status == ReviewStatus.ad
                        ? AppColors.danger700
                        : AppColors.success700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blog.url,
                      style: AppText.caption()
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (blog.status == ReviewStatus.ad) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('광고 감지',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger700)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── 광고 경고 배너 ──
            if (_showWarning) ...[
              AdWarningBanner(blog),
              const SizedBox(height: 12),
            ],

            // ── 블로그 헤더 카드 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 협찬 태그
                    if (blog.isSponsored) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('📢  이 포스팅은 업체로부터 원고료를 제공받았습니다',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.primary500)),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 제목
                    Text(blog.title,
                        style: AppText.title().copyWith(height: 1.4)),
                    const SizedBox(height: 8),

                    // 메타
                    Row(
                      children: [
                        Text(blog.author,
                            style: AppText.caption()
                                .copyWith(color: AppColors.primary500)),
                        const SizedBox(width: 10),
                        Text(blog.date, style: AppText.caption()),
                        const SizedBox(width: 8),
                        StatusBadge(blog.status),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 12),

                    // 광고 확률 바
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('광고 확률', style: AppText.caption()),
                        Text('${blog.adProbability}%',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _progTextColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: blog.adProbability / 100,
                        backgroundColor: AppColors.bg,
                        valueColor: AlwaysStoppedAnimation(_progColor),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 블로그 본문 카드 ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  blog.content,
                  style: AppText.body(),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // ── 하단 액션 버튼 ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.list_rounded, size: 16),
                    label: const Text('다른 리뷰 보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side:
                          const BorderSide(color: AppColors.border, width: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openOriginal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('원문 보기'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
