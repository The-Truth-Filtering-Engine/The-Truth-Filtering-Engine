from openai import AsyncOpenAI
import os, json

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

async def classify_ad(review: dict) -> int:
    text = f"제목: {review['review_title']}\n내용: {review['review_description']}\n블로거: {review['review_bloggername']}"
    
    response = await client.chat.completions.create(
        model="gpt-4o",
        max_tokens=100,
        messages=[
            {
                "role": "system",
                "content": """당신은 네이버 블로그 광고 판별 전문가입니다. url으로 절대 접속하면 안됩니다.
                            아래 블로그 내용이 광고인지 분석하고 JSON으로만 응답하세요 (마크다운 없이):
                            {"is_ad": 0 또는 1}
                            광고 판별 기준: 협찬/제공/무료체험 언급, 과도한 긍정 표현, 가격 강조 없음, 과도한 해시태그"""
            },
            {"role": "user", "content": text}
        ]
    )
    result = json.loads(response.choices[0].message.content)
    return result["is_ad"]


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