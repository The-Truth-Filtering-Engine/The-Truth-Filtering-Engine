# Search Issue Keyword Seed

This seed is finalized after the API spec, Flutter models, and DB schema draft.
The MVP maps user queries and review keywords to curated issue chips with
keyword counting.

| id | label | keyword | aliases | review keywords |
| --- | --- | --- | --- | --- |
| sweet-dessert | 달콤한 디저트가 당길 때 | 달콤 | 디저트, 당충전, 케이크, 라떼 | 달콤, 달달, 케이크, 크림, 디저트, 라떼 |
| spicy-relief | 매운맛으로 스트레스 풀고 싶을 때 | 매운맛 | 매움, 얼큰, 마라, 불닭 | 맵다, 매콤, 얼얼, 칼칼, 마라, 불맛 |
| rainy-day | 비 오는 날 생각나는 메뉴 | 비오는날 | 비, 전, 국물, 칼국수 | 국물, 따뜻, 전, 칼국수, 수제비, 막걸리 |
| hangover | 해장이 필요할 때 | 해장 | 국밥, 라멘, 짬뽕, 쌀국수 | 해장, 얼큰, 국물, 든든, 속풀이 |
| healthy-light | 가볍고 건강하게 먹고 싶을 때 | 건강식 | 샐러드, 포케, 저칼로리 | 신선, 가볍, 샐러드, 포케, 담백 |
| date-night | 데이트하기 좋은 분위기 | 데이트 | 분위기, 와인, 파스타 | 분위기, 조용, 와인, 파스타, 기념일 |
| late-night | 늦은 시간 든든하게 먹고 싶을 때 | 야식 | 심야, 술안주, 치킨 | 야식, 늦게, 술안주, 치킨, 튀김 |
| study-cafe | 오래 머물기 좋은 카페 | 카공 | 공부, 콘센트, 조용한카페 | 콘센트, 조용, 넓다, 좌석, 카공 |

## MVP Mapping Rule

```text
1. Normalize query and review text.
2. Count exact keyword and alias occurrences.
3. Keep only positive review contexts when sentiment data exists.
4. Rank issue chips by matched count and configured base score.
5. Return top 3 issue chips in preview search.
```
