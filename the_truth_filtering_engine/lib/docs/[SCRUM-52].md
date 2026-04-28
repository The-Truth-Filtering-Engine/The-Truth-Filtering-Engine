# Flutter Web KakaoMap Migration Guide

이 문서는 기존 `flutter_map` 기반 지도 화면을 Kakao 지도 Web JavaScript API 기반으로 교체한 과정을 정리한다. 현재 목표는 Chrome에서 실행되는 Flutter Web이며, Android/iOS는 나중에 붙일 수 있도록 조건부 import 구조만 준비했다.

## 1. 전환 목표

기존 구조는 Flutter 내부 위젯으로 지도를 그렸다.

- `flutter_map`
- `latlong2`
- `FlutterMap`
- `TileLayer`
- `MarkerLayer`
- `MapController`

전환 후 구조는 Web에서 Kakao JavaScript SDK가 실제 지도를 그리고, Flutter는 그 위에 검색바, 컨트롤 버튼, 바텀시트 같은 앱 UI를 얹는다.

- Web: Kakao 지도 JavaScript SDK
- 지도 표시: `HtmlElementView`
- 마커 표시: Kakao `CustomOverlay`
- 현재 위치 표시: Kakao `CustomOverlay`
- Android/iOS: placeholder stub

## 2. 변경된 핵심 파일

### `lib/features/1-1_map/screens/map_screen.dart`

기존 `FlutterMap` 전체를 제거하고 `KakaoMapView`로 교체했다.

기존 역할:

- FlutterMap 렌더링
- OSM/Carto tile layer 선택
- Flutter marker layer 표시
- `MapController.move()`로 위치 이동
- `MapCamera` 기준으로 뷰포트 검색

변경 후 역할:

- `KakaoMapView`에 음식점 목록, 현재 위치, 이벤트 콜백 전달
- Kakao 지도 idle 이벤트를 받아 주변 음식점 검색
- 기존 검색바, 위치 버튼, 줌 버튼, 레이어 버튼, 바텀시트 유지
- 마커 클릭 시 `selectedRestaurantProvider` 갱신

### `lib/features/1-1_map/widgets/kakao_map_view.dart`

조건부 import 진입점이다.

```dart
export 'kakao_map_view_stub.dart'
    if (dart.library.html) 'kakao_map_view_web.dart';
```

Flutter Web에서는 `kakao_map_view_web.dart`가 사용되고, Web이 아닌 플랫폼에서는 `kakao_map_view_stub.dart`가 사용된다. 이 구조 덕분에 나중에 Android/iOS 구현을 별도 파일로 추가할 수 있다.

### `lib/features/1-1_map/widgets/kakao_map_view_web.dart`

Web 전용 KakaoMap 구현이다.

주요 기능:

- 백엔드 `/config`에서 `kakaoJsKey` 조회
- Kakao 지도 SDK 동적 로드
- `HtmlElementView`로 DOM 영역 생성
- `kakao.maps.Map` 생성
- `idle` 이벤트를 Flutter callback으로 전달
- 음식점 마커를 `CustomOverlay`로 표시
- 현재 위치를 별도 overlay로 표시
- 줌 인/아웃 처리
- 지도 타입 ROADMAP/SKYVIEW 토글

### `lib/features/1-1_map/widgets/kakao_map_view_stub.dart`

Web 외 플랫폼용 임시 구현이다.

현재는 실제 지도를 띄우지 않고 다음 문구를 보여준다.

```text
카카오맵은 현재 Chrome 웹에서만 지원됩니다
```

나중에 Android/iOS를 붙일 때 이 파일을 네이티브용 구현으로 대체하거나, 플랫폼별 추가 조건부 import를 확장하면 된다.

### `lib/features/1-1_map/models/map_point.dart`

`latlong2` 제거를 위해 앱 내부 좌표 타입을 추가했다.

추가된 타입:

- `MapPoint`
- `MapBounds`
- `KakaoMapCamera`

추가된 유틸:

- `distanceMeters()`

이전에는 `latlong2.LatLng`, `LatLngBounds`, `Distance`를 썼지만, 지도 패키지 교체 후에도 앱 로직이 특정 지도 패키지 타입에 묶이지 않도록 내부 타입으로 분리했다.

### `lib/features/1-1_map/providers/map_provider.dart`

현재 위치 provider 타입을 변경했다.

기존:

```dart
StateProvider<LatLng?>
```

변경 후:

```dart
StateProvider<MapPoint?>
```

### `backend/main.py`

Flutter Web이 Kakao JavaScript 키를 백엔드에서 가져올 수 있도록 `/config` 엔드포인트를 추가했다.

```python
@app.get("/config")
def config():
    return {"kakaoJsKey": os.getenv("KAKAO_JS_KEY", "").strip()}
```

백엔드는 시작 시 `backend/.env`를 로드한다.

```python
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BASE_DIR / ".env")
```

따라서 Kakao JavaScript 키는 다음 파일에 둔다.

```text
backend/.env
```

예시:

```env
KAKAO_JS_KEY=YOUR_KAKAO_JAVASCRIPT_KEY
```

실제 키 값은 문서나 Git에 남기지 않는다.

### `pubspec.yaml`

기존 지도 패키지 의존성을 제거했다.

제거:

```yaml
flutter_map: ^7.0.2
latlong2: ^0.9.1
```

`flutter pub get`을 다시 실행해서 `pubspec.lock`에서도 관련 transitive dependency가 제거되었다.

## 3. 지도 초기화 흐름

현재 Flutter Web에서 지도가 뜨는 흐름은 다음과 같다.

1. `MapScreen`이 `KakaoMapView`를 렌더링한다.
2. `KakaoMapView`가 Web 환경에서 `kakao_map_view_web.dart` 구현으로 연결된다.
3. `HtmlElementView`가 지도를 넣을 DOM `div`를 만든다.
4. `_initializeMap()`이 실행된다.
5. Flutter Web이 백엔드에 요청한다.

```text
GET http://localhost:8000/config
```

6. 백엔드는 `.env`의 `KAKAO_JS_KEY`를 읽어 응답한다.

```json
{"kakaoJsKey":"..."}
```

7. Flutter Web이 Kakao SDK 스크립트를 동적으로 로드한다.

```text
https://dapi.kakao.com/v2/maps/sdk.js?appkey=...&autoload=false
```

8. SDK 로드 후 `kakao.maps.load(...)` 콜백 안에서 지도를 생성한다.
9. 지도 생성 후 음식점 overlay, 현재 위치 overlay, idle 이벤트를 연결한다.

## 4. 이벤트와 데이터 흐름

### 지도 이동 후 주변 음식점 검색

Kakao 지도에서 `idle` 이벤트가 발생하면 `KakaoMapCamera`를 만들어 Flutter로 전달한다.

전달 정보:

- center latitude
- center longitude
- bounds southWest
- bounds northEast
- Kakao level

`MapScreen`은 이 정보를 사용해 검색 radius를 계산하고 기존 백엔드 API를 호출한다.

```text
GET http://localhost:8000/places/nearby-restaurants
```

쿼리 파라미터:

- `lat`
- `lng`
- `radius`
- `display=50`

응답 음식점 목록은 기존 `RestaurantModel`로 변환되고, 다시 `KakaoMapView`에 전달되어 overlay가 갱신된다.

### 마커 클릭

Kakao `CustomOverlay`는 HTML button으로 만들어진다. 클릭 시 Dart callback을 호출한다.

결과:

```dart
selectedRestaurantProvider
```

가 갱신되고 기존 `RestaurantBottomSheet`가 열린다.

### 현재 위치

현재 위치는 기존처럼 `geolocator`로 가져온다.

흐름:

1. 위치 권한 확인
2. 권한 요청
3. 현재 위치 조회
4. `currentLocationProvider`에 `MapPoint` 저장
5. `KakaoMapView.moveTo()` 호출
6. Kakao 지도 center 이동
7. 현재 위치 overlay 표시

### 줌 인/아웃

`flutter_map`의 zoom은 숫자가 커질수록 확대된다. Kakao Map의 level은 반대로 숫자가 작을수록 확대된다.

따라서 변환 후 로직은 다음과 같다.

- 줌 인: `level - 1`
- 줌 아웃: `level + 1`

## 5. 실행 순서

### 1. 백엔드 `.env` 확인

```env
KAKAO_JS_KEY=YOUR_KAKAO_JAVASCRIPT_KEY
```

여기에는 Kakao 앱 키 중 반드시 JavaScript 키를 넣는다. REST API 키를 넣으면 안 된다.

### 2. 백엔드 서버 실행

```powershell
cd C:\Users\user\Desktop\The-Truth-Filtering-Engine\backend
uvicorn main:app --reload
```

확인:

```text
http://localhost:8000/config
```

정상 응답 예:

```json
{"kakaoJsKey":"YOUR_KAKAO_JAVASCRIPT_KEY"}
```

### 3. Flutter Web 실행

포트를 고정하는 것을 권장한다.

```powershell
cd C:\Users\user\Desktop\The-Truth-Filtering-Engine\the_truth_filtering_engine
flutter run -d chrome --web-port 8080
```

포트를 고정하지 않으면 Flutter가 다음처럼 임의 포트를 사용할 수 있다.

```text
http://localhost:59140
```

Kakao 콘솔의 Web 플랫폼 등록값과 실제 Flutter 실행 주소가 반드시 같아야 한다.

## 6. Kakao 개발자 콘솔 설정

Kakao 지도 Web API는 요청 페이지의 origin을 검사한다. 따라서 실제 Flutter 앱 주소를 Kakao 개발자 콘솔에 등록해야 한다.

권장 등록:

```text
http://localhost:8080
```

임의 포트로 실행 중이면 실제 주소를 등록해야 한다.

예:

```text
http://localhost:59140
```

주의:

- `localhost`와 `127.0.0.1`은 다르게 취급된다.
- `http://localhost:8080`과 `http://localhost:59140`도 다르게 취급된다.
- 포트가 바뀌면 다시 등록하거나 Flutter 실행 포트를 고정해야 한다.

## 7. 디버깅 과정에서 확인한 문제

### `Kakao 지도 SDK 로드 실패`

처음에는 앱 화면에 다음 에러가 표시되었다.

```text
Bad state: Kakao 지도 SDK 로드 실패
```

이는 Flutter 코드가 Kakao SDK 스크립트를 로드하지 못했다는 뜻이다.

확인한 요청:

```text
https://dapi.kakao.com/v2/maps/sdk.js?appkey=...&autoload=false
```

Chrome DevTools Network에서 상태가 다음처럼 나왔다.

```text
Status Code: 401 Unauthorized
referer: http://localhost:59140/
```

원인은 Kakao 개발자 콘솔에 실제 Flutter 실행 주소인 `http://localhost:59140`이 등록되어 있지 않았기 때문이다.

해결:

```text
http://localhost:59140
```

를 Kakao Web 플랫폼에 추가하자 지도가 정상 표시되고 현재 위치도 정상 동작했다.

### `Response was blocked by CORB`

Chrome Console에 다음 메시지도 보였다.

```text
Response was blocked by CORB
```

이 메시지는 Kakao SDK 요청이 401 에러 JSON 응답을 받았고, 브라우저가 cross-origin script 응답으로 처리하지 못해 막았다는 단서였다. 실제 원인은 CORB 자체가 아니라 401 Unauthorized였다.

### `Intl.v8BreakIterator is deprecated`

다음 경고도 보였다.

```text
Intl.v8BreakIterator is deprecated. Please use Intl.Segmenter instead.
```

이 경고는 지도 로드 실패의 원인이 아니며, Chrome/라이브러리 쪽 deprecation warning으로 보고 무시했다.

## 8. 검증한 명령

백엔드 문법 확인:

```powershell
python -m py_compile backend\main.py
```

백엔드가 `.env`의 키를 읽는지 값 노출 없이 확인:

```powershell
python -c "import sys; sys.path.insert(0, 'backend'); import main; print(bool(main.config().get('kakaoJsKey')))"
```

Flutter 지도 관련 파일 분석:

```powershell
flutter analyze lib\features\1-1_map\widgets\kakao_map_view_web.dart
```

Flutter Web 빌드:

```powershell
flutter build web
```

기존 패키지 참조 제거 확인:

```powershell
rg "flutter_map|latlong2" pubspec.yaml pubspec.lock lib
```

## 9. 현재 상태

완료된 것:

- `flutter_map` 지도 렌더링 제거
- Kakao JavaScript Map 렌더링 추가
- 음식점 마커를 Kakao overlay로 표시
- 현재 위치 overlay 표시
- 지도 이동 후 주변 음식점 재검색 유지
- 검색바, 바텀시트, 북마크, 상세 이동 유지
- 백엔드 `.env`의 `KAKAO_JS_KEY`를 Flutter Web에서 사용
- Chrome에서 지도 표시와 현재 위치 확인

남은 개선 가능 지점:

- Flutter 실행 포트를 항상 `8080`으로 고정해서 Kakao 콘솔 설정을 안정화
- `/config` 응답에 키가 없을 때 사용자 친화적 메시지 개선
- Android/iOS용 Kakao 지도 구현 추가
- `KakaoMapView` interface를 더 일반화해서 플랫폼별 구현 교체를 쉽게 만들기
- 전체 `flutter analyze`에서 기존 unrelated warning 정리
