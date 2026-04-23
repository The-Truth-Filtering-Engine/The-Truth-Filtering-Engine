# The-Truth-Filtering-Engine

- 필요한 언어/프레임워크 버전
- 설치 시작 방법
- 실행 방법

# the_truth_filtering_engine

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# Truth Map — 셋업 가이드

## 📁 파일 구조

```
lib/
├── main.dart
├── core/
│   └── theme/
│       ├── app_colors.dart
│       └── app_text_styles.dart
├── features/
│   └── map/
│       ├── models/
│       │   └── restaurant_model.dart
│       ├── providers/
│       │   └── map_provider.dart
│       ├── screens/
│       │   └── map_screen.dart
│       └── widgets/
│           ├── map_search_bar.dart
│           ├── map_control_buttons.dart
│           ├── truth_score_marker.dart
│           ├── truth_score_badge.dart
│           └── restaurant_bottom_sheet.dart
```

---

## 🚀 실행 전 필수 설정

### 1. 패키지 설치
```bash
flutter pub get
```

### 2. 네이버 지도 클라이언트 ID 발급
- [네이버 클라우드 플랫폼](https://www.ncloud.com/) → Application 등록
- **Android**: `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data
    android:name="com.naver.maps.map.CLIENT_ID"
    android:value="YOUR_CLIENT_ID" />
```
- **iOS**: `ios/Runner/Info.plist`
```xml
<key>NMFClientId</key>
<string>YOUR_CLIENT_ID</string>
```
- `lib/main.dart`의 `clientId` 값도 교체

### 3. (선택) Pretendard 폰트 추가
```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Regular.ttf
        - asset: assets/fonts/Pretendard-Bold.ttf
          weight: 700
```

---

## 🧩 컴포넌트 설명

| 컴포넌트 | 역할 |
|---|---|
| `MapSearchBar` | 상단 검색창 |
| `TruthScoreMarker` | 지도 위 점수 말풍선 마커 |
| `MapControlButtons` | GPS·레이어·줌 플로팅 버튼 |
| `RestaurantBottomSheet` | 하단 식당 정보 카드 |
| `TruthScoreBadge` | TRUTH 점수 다크 뱃지 (재사용) |

---

