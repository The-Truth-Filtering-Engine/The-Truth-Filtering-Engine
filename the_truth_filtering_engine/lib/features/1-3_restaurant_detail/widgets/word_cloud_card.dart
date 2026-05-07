import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── 워드 빈도 모델 ─────────────────────────────────────────────────────────────

class WordFreq {
  final String word;
  final int freq;
  const WordFreq(this.word, this.freq);
}

// ── 워드클라우드 카드 ──────────────────────────────────────────────────────────

class WordCloudCard extends StatelessWidget {
  final List<WordFreq> wordFreqs;

  const WordCloudCard({super.key, required this.wordFreqs});

  @override
  Widget build(BuildContext context) {
    return Container(
      // 높이를 부모(IntrinsicHeight Row)에 맞게 stretch
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4EC), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Row(
            children: const [
              Icon(Icons.tag_rounded, size: 15, color: Color(0xFF2B54E8)),
              SizedBox(width: 6),
              Text(
                '리뷰 키워드',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E4E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 말풍선 워드클라우드 ──
          Flexible(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(
                painter: BubbleWordCloudPainter(wordFreqs),
                size: Size.infinite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 말풍선 Painter ─────────────────────────────────────────────────────────────

class BubbleWordCloudPainter extends CustomPainter {
  final List<WordFreq> words;

  BubbleWordCloudPainter(this.words);

  static const _palette = [
    Color(0xFF2B54E8),
    Color(0xFF4CBB87),
    Color(0xFFE85C5C),
    Color(0xFFF5A623),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFF2980B9),
    Color(0xFFE74C3C),
    Color(0xFF16A085),
  ];

  /// 말풍선 외곽 경로 — 꼬리는 하단 중앙
  Path _bubblePath(Size size) {
    const r = 16.0; // 모서리 반경
    const tailW = 18.0; // 꼬리 너비
    const tailH = 12.0; // 꼬리 높이
    final w = size.width;
    final h = size.height - tailH;
    final cx = w / 2;

    return Path()
      ..moveTo(r, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r),
          radius: const Radius.circular(r), clockwise: true)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h),
          radius: const Radius.circular(r), clockwise: true)
      ..lineTo(cx + tailW / 2, h)
      ..lineTo(cx, h + tailH) // 꼬리 끝
      ..lineTo(cx - tailW / 2, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r),
          radius: const Radius.circular(r), clockwise: true)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0),
          radius: const Radius.circular(r), clockwise: true)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty) return;

    const tailH = 12.0;
    final bubbleSize = Size(size.width, size.height);

    // ── 말풍선 배경 ──
    final bgPaint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = const Color(0xFFE4E4EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = _bubblePath(bubbleSize);
    canvas.drawPath(path, bgPaint);
    canvas.drawPath(path, borderPaint);

    // ── 텍스트 배치 영역 (꼬리 제외) ──
    final paintArea = Size(size.width, size.height - tailH);
    const padding = EdgeInsets.all(14.0);

    final maxFreq = words.first.freq;
    final placed = <Rect>[];
    final rng = math.Random(42);

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final ratio = w.freq / maxFreq;
      final fontSize = 13.0 + ratio * 14.0; // 13~27px
      final fontWeight = ratio > 0.6 ? FontWeight.w700 : FontWeight.w500;
      final color = _palette[i % _palette.length];

      final tp = TextPainter(
        text: TextSpan(
          text: w.word,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: paintArea.width - padding.horizontal);

      final xMax = (paintArea.width - padding.left - padding.right - tp.width)
          .clamp(0.0, double.maxFinite);
      final yMax = (paintArea.height - padding.top - padding.bottom - tp.height)
          .clamp(0.0, double.maxFinite);

      Offset? pos;
      for (int attempt = 0; attempt < 400; attempt++) {
        final x = padding.left + rng.nextDouble() * xMax;
        final y = padding.top + rng.nextDouble() * yMax;
        final candidate = Rect.fromLTWH(x, y, tp.width + 6, tp.height + 2);

        if (placed.every((r) => !r.overlaps(candidate))) {
          pos = Offset(x, y);
          placed.add(candidate);
          break;
        }
      }

      if (pos != null) tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(BubbleWordCloudPainter old) {
    if (old.words.length != words.length) return true;
    for (int i = 0; i < words.length; i++) {
      if (old.words[i].word != words[i].word ||
          old.words[i].freq != words[i].freq) return true;
    }
    return false;
  }
}

// ── 워드 빈도 계산 유틸 ────────────────────────────────────────────────────────

class WordFreqBuilder {
  static const _stopWords = {
    '의',
    '을',
    '를',
    '이',
    '가',
    '은',
    '는',
    '에',
    '와',
    '과',
    '도',
    '로',
    '으로',
    '에서',
    '하고',
    '이고',
    '하는',
    '있는',
    '없는',
    '한',
    '그',
    '더',
    '및',
    '등',
    '수',
    '것',
    '곳',
    '때',
    '후',
    '전',
    '중',
    '내',
    '위',
    '위한',
    '대한',
    '통해',
    '위해',
    '하여',
    '그리고',
    '하지만',
    '그런데',
    '또한',
    '정말',
    '너무',
    '진짜',
    '매우',
    '아주',
    '완전',
    '되어',
    '해서',
    '하면',
    '이번',
    '다시',
    '처음',
    '마지막',
    '항상',
    '자주',
    '가끔',
    '오늘',
    '어제',
  };

  static List<WordFreq> build(List<String> titles) {
    final freq = <String, int>{};

    for (final title in titles) {
      final cleaned = title.replaceAll(RegExp(r'''["'""''\u0022\u0027]'''), '');
      final wordList = cleaned
          .split(RegExp(r'[\s\[\]「」『』《》<>【】,\.!?\-_/\(\)\|#@&+*：:；;]'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2 && !_stopWords.contains(w));
      for (final w in wordList) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // C방식: 빈도 2회 이상 + 상위 8개
    return sorted
        .where((e) => e.value >= 2)
        .take(8)
        .map((e) => WordFreq(e.key, e.value))
        .toList();
  }
}
