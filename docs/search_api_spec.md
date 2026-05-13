# Search API Spec

## Scope

The app is login-only. All search history and click history APIs require the
Supabase bearer token.

Search history is saved when the user selects a result, not while typing. This
keeps incomplete queries and typos out of the user's history.

## Implementation Order

```text
1. API spec
2. Flutter models
3. DB schema draft
4. Backend endpoints
5. Flutter UI connection
6. Issue keyword seed data
7. Web test script
```

## Preview Search

```http
GET /api/search/preview?query=돌체&lat=37.123&lng=127.123
Authorization: Bearer <supabase-access-token>
```

### Response

```json
{
  "query": "돌체",
  "issueChips": [
    {
      "id": "sweet-dessert",
      "label": "달콤한 디저트가 당길 때",
      "keyword": "달콤",
      "score": 25
    }
  ],
  "suggestions": {
    "menus": [
      {
        "id": "menu-1",
        "name": "돌체라떼",
        "matchedText": "돌체",
        "score": 90
      }
    ],
    "restaurants": [
      {
        "id": "restaurant-1",
        "name": "돌체 베이커리",
        "score": 100
      }
    ]
  },
  "quickPreviews": [
    {
      "restaurantId": "restaurant-1",
      "restaurantName": "돌체 베이커리",
      "menuId": "menu-1",
      "menuName": "돌체 휘낭시에",
      "price": 4500,
      "priceLabel": "4,500원",
      "imageUrl": null,
      "score": 100,
      "matchReason": "가게명 완전일치"
    }
  ]
}
```

## Recent Search

Retention:

```text
Recent search history is kept for 14 days.
Rows older than 14 days are deleted at the DB level.
Search text is saved only when the user selects a result.
Typing-only queries are not saved.
```

```http
GET /api/search/recent
Authorization: Bearer <supabase-access-token>
```

```http
POST /api/search/recent
Authorization: Bearer <supabase-access-token>
Content-Type: application/json
```

```json
{
  "query": "돌체",
  "clickedType": "menu",
  "clickedId": "menu-1",
  "clickedLabel": "돌체라떼",
  "restaurantId": "restaurant-1",
  "menuId": "menu-1"
}
```

```http
DELETE /api/search/recent/{historyId}
DELETE /api/search/recent
```

## Click Types

```text
menu
restaurant
issue
quick_preview
```

## Accuracy Weights

MVP uses accuracy weighting, not popularity weighting.

```text
restaurant exact match: 100
menu exact match: 90
restaurant prefix match: 80
menu prefix match: 70
restaurant partial match: 60
menu partial match: 50
review keyword match: 30
issue tag match: 25
distance boost: excluded from MVP
click/popularity boost: excluded from MVP
```

## Price Rules

```text
price exists: "4,500원"
price missing: "가격 문의"
price range: "8,000~12,000원"
seasonal/variable price: "변동가"
```

## UI States

```text
Before input:
- recent search history
- curated issue chips

While typing:
- issue chips at the top
- menu suggestions
- restaurant suggestions
- quick preview cards with image, menu, restaurant, price

After submit:
- full result page
- accuracy score first
- review keyword counting as MVP relevance signal
```
