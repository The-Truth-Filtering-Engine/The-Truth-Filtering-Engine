import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'bookmark_options.dart';

class BookmarkEditDialog extends StatefulWidget {
  final List<BookmarkTopicOption> topics;
  final Future<BookmarkTopicOption?> Function(String name, String colorKey)
      onCreateTopic;
  final Future<void> Function(BookmarkTopicOption topic) onDeleteTopic;

  const BookmarkEditDialog({
    super.key,
    required this.topics,
    required this.onCreateTopic,
    required this.onDeleteTopic,
  });

  @override
  State<BookmarkEditDialog> createState() => _BookmarkEditDialogState();
}

class _BookmarkEditDialogState extends State<BookmarkEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  late List<BookmarkTopicOption> _topics;
  String _selectedColorKey = BookmarkColors.defaultColorKey;
  bool _isCreating = false;
  bool _isSubmitting = false;
  final Set<String> _deletingTopicIds = {};

  @override
  void initState() {
    super.initState();
    _topics = List.of(widget.topics);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '북마크 편집',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildCreateSection(),
              const Divider(height: 32, color: AppColors.border),
              _buildDeleteSection(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '북마크 만들기',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              tooltip: _isCreating ? '접기' : '펼치기',
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                        _isCreating = !_isCreating;
                      }),
              icon: Icon(
                _isCreating
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (_isCreating) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 12,
            decoration: InputDecoration(
              hintText: '예: 가족 외식',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8F8FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary500),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onCreate(),
          ),
          const SizedBox(height: 12),
          const Text(
            '색깔 선택',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BookmarkColors.items.map(_buildColorDot).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _onCreate,
              style: FilledButton.styleFrom(
                backgroundColor:
                    BookmarkColors.byKey(_selectedColorKey).foreground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(_isSubmitting ? '추가 중...' : '추가'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColorDot(BookmarkColorOption color) {
    final isSelected = _selectedColorKey == color.key;
    return GestureDetector(
      onTap: _isSubmitting
          ? null
          : () => setState(() {
                _selectedColorKey = color.key;
              }),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: color.label,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.foreground,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : Colors.transparent,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }

  Widget _buildDeleteSection() {
    final deletableTopics = _topics
        .where((topic) => BookmarkTopics.canDeleteTopic(topic.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '북마크 삭제',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (deletableTopics.isEmpty)
          const Text(
            '삭제할 수 있는 북마크가 없어요.\n즐겨찾기는 삭제할 수 없어요.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textHint,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: deletableTopics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final topic = deletableTopics[index];
              final color = BookmarkColors.byKey(topic.colorKey);
              final isDeleting = _deletingTopicIds.contains(topic.id);
              return Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color.foreground,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '북마크 삭제',
                    icon: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    color: AppColors.danger400,
                    onPressed: isDeleting || _isSubmitting
                        ? null
                        : () => _onDelete(topic),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('이름을 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final created = await widget.onCreateTopic(name, _selectedColorKey);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (created == null) {
      _showSnack('이미 있는 북마크예요.');
      return;
    }

    _nameController.clear();
    setState(() {
      _topics = [..._topics, created];
      _isCreating = false;
      _selectedColorKey = BookmarkColors.defaultColorKey;
    });
    _showSnack('\'${created.label}\' 북마크가 추가됐어요.');
  }

  Future<void> _onDelete(BookmarkTopicOption topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('북마크 삭제'),
        content: Text(
          '\'${topic.label}\' 북마크를 삭제할까요?\n안에 있는 맛집도 함께 삭제돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger400),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingTopicIds.add(topic.id);
    });

    await widget.onDeleteTopic(topic);

    if (!mounted) return;
    setState(() {
      _deletingTopicIds.remove(topic.id);
      _topics = _topics.where((item) => item.id != topic.id).toList();
    });
    _showSnack('\'${topic.label}\' 북마크가 삭제됐어요.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
