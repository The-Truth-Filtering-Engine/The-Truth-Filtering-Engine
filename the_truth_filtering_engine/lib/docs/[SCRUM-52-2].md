# Kakao Local REST API 지도 검색 결과 표시 정리

## 1. 작업 목적

Flutter Web에서 카카오맵이 표시된 상태에서, 현재 지도 화면의 중심점을 기준으로 주변 장소를 검색하고 그 결과를 지도 마커로 표시하도록 변경했다.

이번 작업의 핵심은 카카오 지도 JavaScript SDK가 아니라, 카카오 Local REST API를 백엔드에서 호출해 장소 데이터를 가져오는 것이다.

목표는 다음과 같다.

- 현재 카카오맵의 중심 좌표를 기준으로 주변 장소 검색
- 지도 확대 수준에 맞춰 검색 반경 radius 반영
- 카카오 카테고리 코드 중 `FD6`, `CE7`만 사용
- 검색 결과를 최대 10개로 제한
- 검색 결과를 기존 `RestaurantModel`로 변환
- 변환된 데이터를 `KakaoMapView`에 전달해 지도 위 마커로 표시

## 2. 사용한 카카오 문서와 API

참고 문서:

```text
https://developers.kakao.com/docs/ko/local/dev-guide#search-by-category
```

사용한 API:

```text
GET https://dapi.kakao.com/v2/local/search/category.json
```

이 API는 카테고리 그룹 코드를 기준으로 장소를 검색한다.

이번 작업에서 사용한 카테고리 코드는 다음 두 개다.

```text
FD6: 음식점
CE7: 카페
```

카카오 Local REST API는 REST API 키로 인증한다.

요청 헤더:

```text
Authorization: KakaoAK {KAKAO_REST_API_KEY}
```

요청 파라미터:

```text
category_group_code=FD6 또는 CE7
x=지도 중심 경도
y=지도 중심 위도
radius=지도 확대 수준으로 계산한 반경
sort=accuracy 또는 distance
size=10
```

## 3. 키 관리 방식

이번 구조에서는 키를 두 종류로 나눠 사용한다.

```text
KAKAO_JS_KEY
```

카카오 지도 JavaScript SDK 로딩용 키다. Flutter Web 브라우저에서 카카오 지도 SDK를 불러올 때 사용한다.

```text
KAKAO_REST_API_KEY
```

카카오 Local REST API 호출용 키다. 이 키는 Flutter 코드에 직접 넣지 않고 백엔드 `.env`에만 둔다.

백엔드 `.env` 예시:

```env
KAKAO_JS_KEY=...
KAKAO_REST_API_KEY=...
```

실제 키 값은 문서에 남기지 않는다.

## 4. Kakao Developers 설정

### 4.1 Web 플랫폼 도메인

카카오 지도 SDK는 브라우저의 origin을 검사한다.

Flutter Web을 Chrome으로 실행할 때 주소가 다음과 같다면:

```text
http://localhost:59140
```

Kakao Developers의 Web 플랫폼 도메인에도 정확히 같은 값을 등록해야 한다.

```text
http://localhost:59140
```

포트가 다르면 다른 도메인으로 취급된다.

개발 중에는 Flutter Web 포트를 고정하는 것이 좋다.

```powershell
flutter run -d chrome --web-port=59140
```

### 4.2 REST API 호출 허용 IP

카카오 Local REST API는 백엔드 서버에서 호출한다.

로컬 개발 중에는 백엔드가 내 PC에서 실행되므로, 카카오가 보는 호출 IP는 내 네트워크의 공인 IP다.

에러 예시:

```text
ip mismatched! callerIp=59.12.53.205. check out registered ips.
```

이 경우 Kakao Developers의 REST API 호출 허용 IP에 다음처럼 실제 공인 IP를 등록해야 한다.

```text
59.12.53.205
```

`0.0.0.0`, `127.0.0.1`, `localhost`는 이 설정에 넣는 값이 아니다.

출시 환경에서는 사용자 IP를 등록하는 것이 아니라, 배포된 백엔드 서버의 고정 공인 IP만 등록한다.

## 5. 백엔드 변경 내용

수정 파일:

```text
backend/routers/places.py
```

기존 `/places/nearby-restaurants` API를 카카오 Local REST API 기반으로 변경했다.

Flutter에서 호출하는 API 형태:

```text
GET http://localhost:8000/places/nearby-restaurants
```

쿼리 파라미터:

```text
lat=지도 중심 위도
lng=지도 중심 경도
radius=검색 반경
display=10
```

백엔드 내부 흐름:

1. `.env`에서 `KAKAO_REST_API_KEY`를 읽는다.
2. `KAKAO_REST_API_KEY`가 없으면 `500` 에러를 반환한다.
3. Flutter에서 받은 `radius`를 카카오 제한에 맞춰 최대 `20000`으로 제한한다.
4. `FD6`, `CE7` 카테고리를 각각 카카오 Local API에 요청한다.
5. 두 결과를 하나로 합친다.
6. 카카오 장소 `id` 기준으로 중복을 제거한다.
7. 응답 데이터를 앱에서 쓰는 형태로 변환한다.
8. 최대 `display`개만 반환한다.

현재 백엔드의 카카오 요청 URL:

```text
https://dapi.kakao.com/v2/local/search/category.json
```

현재 사용 카테고리:

```python
KAKAO_PLACE_CATEGORY_CODES = ("FD6", "CE7")
```

현재 요청 파라미터 핵심:

```python
params = {
    "category_group_code": category_code,
    "x": lng,
    "y": lat,
    "radius": radius,
    "sort": "accuracy",
    "size": display,
}
```

주의할 점:

현재 코드는 카카오 요청에는 `sort=accuracy`를 사용하지만, 최종 반환 전에 `distance` 기준으로 다시 정렬하는 코드가 남아 있다.

```python
restaurants = sorted(
    unique_by_id.values(),
    key=lambda restaurant: restaurant["distance"],
)[:display]
```

따라서 최종 지도 표시 순서는 현재 코드 기준으로 거리순에 가깝다.

카카오 정확도순을 그대로 유지하려면 위 정렬을 제거하고 다음처럼 바꾸면 된다.

```python
restaurants = list(unique_by_id.values())[:display]
```

## 6. 백엔드 응답 형태

백엔드는 카카오 응답을 그대로 Flutter에 넘기지 않고, 기존 지도 화면에서 쓰기 쉬운 형태로 변환한다.

응답 예시:

```json
{
  "count": 10,
  "restaurants": [
    {
      "id": "123456789",
      "name": "장소명",
      "address": "도로명 또는 지번 주소",
      "category": "카페",
      "lat": 37.2888,
      "lng": 127.0472,
      "link": "https://place.map.kakao.com/...",
      "distance": 120,
      "phone": "031-..."
    }
  ]
}
```

카카오 응답 필드와 앱 응답 필드 매핑:

```text
id -> id
place_name -> name
road_address_name 또는 address_name -> address
category_name -> category
y -> lat
x -> lng
place_url -> link
distance -> distance
phone -> phone
```

`category_name`은 `음식점 > 한식 > 육류,고기`처럼 내려올 수 있으므로, `parse_kakao_category()`에서 마지막 카테고리명만 뽑아 표시한다.

## 7. Flutter 지도 화면 변경 내용

수정 파일:

```text
the_truth_filtering_engine/lib/features/1-1_map/screens/map_screen.dart
```

지도 화면은 카카오맵에서 idle 이벤트가 발생할 때마다 현재 카메라 정보를 받는다.

카메라 정보:

```text
center: 현재 지도 중심점
bounds: 현재 지도 화면 경계
level: 현재 지도 확대 수준
```

`MapScreen`은 이 값을 사용해 검색 반경을 계산한다.

반경 계산 방식:

1. 지도 bounds의 북동, 남서 좌표를 가져온다.
2. 북서, 남동 좌표를 추가로 만든다.
3. 지도 중심점에서 네 모서리까지의 거리를 계산한다.
4. 가장 먼 거리를 radius로 사용한다.
5. 최소 `100m`, 최대 `20000m`로 제한한다.

이렇게 계산한 radius를 백엔드에 전달한다.

Flutter 요청 예시:

```text
GET http://localhost:8000/places/nearby-restaurants
  ?lat=37.28888443771373
  &lng=127.0472743938611
  &radius=405
  &display=10
```

현재 지도 화면의 최대 표시 개수:

```dart
static const int _maxMapRestaurants = 10;
```

백엔드 요청에서도 `display=10`을 보낸다.

```dart
'display': '10',
```

## 8. 지도 마커 표시 흐름

전체 흐름은 다음과 같다.

```text
사용자가 지도를 이동하거나 확대/축소
  -> KakaoMapView idle 이벤트 발생
  -> MapScreen이 center, bounds, level 수신
  -> MapScreen이 radius 계산
  -> /places/nearby-restaurants 호출
  -> 백엔드가 Kakao Local REST API 호출
  -> FD6/CE7 결과를 RestaurantModel 형태로 변환
  -> KakaoMapView에 restaurants 전달
  -> CustomOverlay 마커로 지도에 표시
```

`KakaoMapView`는 `RestaurantModel.category`를 보고 마커 아이콘을 다르게 표시한다.

```text
카페 계열: ☕
그 외 음식점: 🍽️
```

마커를 누르면 기존처럼 `selectedRestaurantProvider`에 선택된 음식점이 저장되고, 하단 상세 패널이 열린다.

## 9. 에러와 해결 과정

### 9.1 지도 SDK 로드 실패

증상:

```text
Kakao 지도 SDK 로드 실패
```

원인:

Flutter Web 실행 포트가 바뀌었는데, Kakao Developers Web 플랫폼 도메인에 새 포트가 등록되지 않았다.

해결:

```powershell
flutter run -d chrome --web-port=59140
```

그리고 Kakao Developers에 다음 도메인 등록:

```text
http://localhost:59140
```

### 9.2 Local API 401 Unauthorized

증상:

```text
카카오 Local API 에러 category=FD6 status=401
ip mismatched! callerIp=...
```

원인:

카카오 REST API 호출 허용 IP에 현재 백엔드가 나가는 공인 IP가 등록되어 있지 않았다.

해결:

Kakao Developers의 REST API 호출 허용 IP에 에러 메시지의 `callerIp` 값을 등록한다.

### 9.3 0.0.0.0 등록 문제

`0.0.0.0`은 모든 IP 허용 의미로 처리되지 않는다.

로컬 개발에서는 현재 공인 IP를 직접 등록하거나, 카카오 설정에서 허용 IP 제한을 비울 수 있는지 확인해야 한다.

출시 환경에서는 백엔드 서버의 고정 공인 IP를 등록한다.

## 10. 실행 순서

백엔드 `.env` 확인:

```env
KAKAO_JS_KEY=...
KAKAO_REST_API_KEY=...
```

백엔드 서버 재시작:

```powershell
cd C:\Users\user\Desktop\The-Truth-Filtering-Engine\backend
uvicorn main:app --reload
```

Flutter Web 실행:

```powershell
cd C:\Users\user\Desktop\The-Truth-Filtering-Engine\the_truth_filtering_engine
flutter run -d chrome --web-port=59140
```

브라우저에서 지도 화면 진입 후 확인:

- 카카오맵이 뜨는지
- 현재 위치가 잡히는지
- 지도 중심 기준 주변 음식점/카페 마커가 뜨는지
- 지도 이동 또는 확대/축소 후 결과가 갱신되는지

## 11. 현재 상태

현재 구현 상태:

- 카카오맵 SDK 로드 성공
- 현재 위치 표시 성공
- 카카오 Local REST API 호출 성공
- `FD6`, `CE7` 카테고리 검색 결과 표시 성공
- 지도 중심점과 확대 수준에 따른 radius 반영
- 최대 10개 장소 표시

남아 있는 개선 후보:

- 정렬 방식을 API 파라미터로 선택 가능하게 만들기
- `accuracy` 정렬을 그대로 유지하려면 백엔드의 최종 거리순 정렬 제거
- 카테고리 필터를 UI에서 음식점/카페 선택 가능하게 만들기
- 백엔드 API URL을 `localhost:8000` 하드코딩 대신 환경값으로 분리
- 출시 시 백엔드 서버 고정 공인 IP와 서비스 도메인 기준으로 Kakao Developers 설정 정리
