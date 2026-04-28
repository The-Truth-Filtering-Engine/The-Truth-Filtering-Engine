import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── 워드 빈도 모델 (외부에서도 사용) ──────────────────────────────────────────

class WordFreq {
  final String word;
  final int freq;
  const WordFreq(this.word, this.freq);
}

// ── 워드클라우드 카드 ─────────────────────────────────────────────────────────

class WordCloudCard extends StatelessWidget {
  final List<WordFreq> wordFreqs;

  const WordCloudCard({super.key, required this.wordFreqs});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const SizedBox(height: 2),
          const Text(
            '블로그 제목에서 추출한 주요 키워드',
            style: TextStyle(fontSize: 11, color: Color(0xFF9090A8)),
          ),
          const SizedBox(height: 12),

          // ── 워드클라우드 캔버스 ──
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: WordCloudPainter(wordFreqs),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 워드클라우드 Painter ──────────────────────────────────────────────────────

class WordCloudPainter extends CustomPainter {
  final List<WordFreq> words;

  WordCloudPainter(this.words);

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

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty) return;

    final maxFreq = words.first.freq;
    final placed = <Rect>[];
    final rng = math.Random(42); // 고정 시드 → 동일 레이아웃

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final ratio = w.freq / maxFreq;
      final fontSize = 12.0 + ratio * 16.0; // 12~28px
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
      )..layout(maxWidth: size.width);

      Offset? pos;
      for (int attempt = 0; attempt < 300; attempt++) {
        final x =
            rng.nextDouble() * (size.width - tp.width).clamp(0, size.width);
        final y =
            rng.nextDouble() * (size.height - tp.height).clamp(0, size.height);
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
  bool shouldRepaint(WordCloudPainter old) {
    if (old.words.length != words.length) return true;
    for (int i = 0; i < words.length; i++) {
      if (old.words[i].word != words[i].word ||
          old.words[i].freq != words[i].freq) return true;
    }
    return false;
  }
}

// ── 워드 빈도 계산 유틸 ───────────────────────────────────────────────────────

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
      final words = title
          .split(RegExp(r'[\s\[\]「」『』《》<>【】,\.!?\-_/\(\)\|#@&+*]'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2 && !_stopWords.contains(w));
      for (final w in words) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(30).map((e) => WordFreq(e.key, e.value)).toList();
  }
}
