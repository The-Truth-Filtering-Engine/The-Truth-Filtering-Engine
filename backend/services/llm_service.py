from openai import AsyncOpenAI
import os, json


client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))


async def classify_ad(review: dict) -> float:
    text = f"제목: {review['review_title']}\n내용: {review['review_description']}\n블로거: {review['review_bloggername']}"
 
    response = await client.chat.completions.create(
        model="gpt-4o",
        max_tokens=100,
        temperature=0,  # 일관성 확보
        messages=[
            {
                "role": "system",
                "content": """당신은 네이버 블로그 광고 판별 전문가입니다.
절대로 URL에 접속하지 말고, 입력된 텍스트만으로 판단하세요.
 
[1] 기본 점수: 0.3 (중립)
 
[2] 아래 신호가 있으면 점수를 조정하세요
(광고 신호 - 점수 증가)
- 협찬/제공/무료체험/PPL 명시: +0.7
- 일방적 칭찬만 있고 단점 없음: +0.2
- 가격·링크·예약 유도 CTA: +0.15
- 정보 나열형 (주소·영업시간·메뉴 나열): +0.1
- 해시태그 10개 이상: +0.1
 
(진성 리뷰 신호 - 점수 감소)
- 단점·불만 명시적 언급: -0.4
- 부정적 감정 포함 (아쉬웠다/불편/별로): -0.2
- 구체적 개인 경험 묘사: -0.1
- 자연스러운 구어체 문체: -0.1
 
[3] 최종 점수 = 기본점수 + 합산, 범위 0.0~1.0으로 제한
 
[4] JSON만 출력 (설명 금지):
{"is_ad_prob": 숫자}"""
            },
            {"role": "user", "content": text}
        ]
    )
 
    try:
        result = json.loads(response.choices[0].message.content)
        return float(result["is_ad_prob"])
    except (json.JSONDecodeError, KeyError, ValueError):
        return 0.5  # 판별 실패 시 중립값 반환
   




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

