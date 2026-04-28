from openai import AsyncOpenAI
import os, json

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

async def classify_ad(review: dict) -> float:
    text = f"제목: {review['review_title']}\n내용: {review['review_description']}\n블로거: {review['review_bloggername']}"
    
    response = await client.chat.completions.create(
        model="gpt-4o",
        max_tokens=100,
        messages=[
            {
                "role": "system",
                "content": """당신은 네이버 블로그 광고 판별 전문가입니다. url으로 절대 접속하면 안됩니다.
아래 블로그 내용이 광고일 확률을 분석하고 JSON으로만 응답하세요 (마크다운 없이):
{"is_ad_prob": 0.0~1.0 사이 소수}

확률 기준:
- 0.0~0.3: 명백한 진성 리뷰 (개인 경험 중심, 단점 언급, 자연스러운 문체)
- 0.3~0.6: 광고 의심 (긍정 표현 과다하나 협찬 명시 없음)
- 0.6~1.0: 명백한 광고 (협찬/제공/무료체험 언급, 가격 강조 없음, 과도한 해시태그, 일방적 칭찬)"""
            },
            {"role": "user", "content": text}
        ]
    )
    result = json.loads(response.choices[0].message.content)
    return float(result["is_ad_prob"])  # 키 수정 + float 변환
    


async def summarize_reviews(reviews: list[dict]) -> str:
    real_reviews = [
        f"제목: {r['review_title']}\n내용: {r['review_description']}"
        for r in reviews
        if r.get("is_ad_llm_pred") == 0
    ]

    if not real_reviews:
        return "진짜 리뷰가 없습니다."

    combined = "\n\n".join(real_reviews)
    response = await client.chat.completions.create(
        model="gpt-4o-mini",
        max_tokens=300,
        messages=[
            {"role": "system", "content": "광고가 아닌 진짜 리뷰들을 3줄로 요약해주세요."},
            {"role": "user", "content": combined}
        ]
    )
    return response.choices[0].message.content