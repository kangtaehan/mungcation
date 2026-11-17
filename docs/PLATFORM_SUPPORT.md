# 플랫폼 지원 범위

2026-11-17 현재 소스 기준. 구현 여부와 실기기 검증 여부는 다르다.

| 기능 | Android 앱 | iOS 앱 | 실제 웹 앱 (`main_web.dart`) | UI 미리보기 (`main_preview.dart`) |
|---|---|---|---|---|
| 프로필·성장·꾸미기 | 로컬 저장 | 로컬 저장 | 브라우저 저장 | 예시 프로필·장착 저장 |
| 지도·장소·도보 경로 | OSM·Nominatim·OSRM | MapKit | OSM·Nominatim·OSRM, CORS 필요 | 예시 지도 |
| GPS 기록 | 구현 | 구현 | HTTPS/localhost와 브라우저 권한 필요 | 예시 |
| 잠금 화면 기록 | 선택형 foreground service | 선택형 위치 업데이트 | 지원하지 않음 | 지원하지 않음 |
| 사진·픽셀 변환 | 구현 | 구현 | 버튼 비활성·모바일 안내 | 모바일 안내 |
| 통계·달력·즐겨찾기 | 구현 | 구현 | 구현 | 예시 |
| JSON 백업·복원 | 문서 선택·저장 | 공유·문서 선택 | 지원하지 않음 | 지원하지 않음 |
| GPX 내보내기 | 구현 | 구현 | 모바일 안내 | 모바일 안내 |
| 외부 지도·출처 | Android intent | Apple 지도·네이티브 지도 표기 | 새 브라우저 탭 | 예시 |

웹 저장소는 계정 동기화가 아니며 브라우저 데이터 삭제·비공개 탐색·기기 변경 시 유지되지 않을 수 있다. 웹에서는 앱 전환·탭 비활성화·화면 잠금 후 기록 지속을 보장하지 않는다. 모바일 백업은 웹으로 가져오지 않는다.

## 추천과 길안내

- 크기별 기본 필터는 소형 30분·중형 45분·대형 60분이다. 의료적 운동 권장량이 아니며 건강·나이에 따라 사용자가 조절한다.
- 주변 장소 예상 시간은 직선거리 × 왕복 × 도로 보정계수 1.3 ÷ 분당 75m다. 선택 후 공급자가 반환한 실제 경로 거리·시간을 별도로 보여준다.
- 같은 길 귀환 시 진행 거리를 유지해 왕로와 귀로를 구분한다. 이탈 재탐색은 처음 정한 출발점을 귀환점으로 유지한다. 목적지 근처 도달 후 재탐색은 출발점으로 직접 안내한다.
- 최초 귀환 경로 요청 실패 시 공급자의 왕로를 역순으로 연결한 같은 길 코스임을 표시한다. 재탐색 때 귀환 경로를 얻지 못하면 이동한 위치를 새 귀환점으로 만들지 않고 오류를 표시한다.
- 현재 인도·횡단보도 구조 데이터는 없다. 도로 이름의 공원·산책로 표현을 확인된 인도나 안전 점수로 표시하지 않는다. 위험 도로 표현은 참고 경고로만 사용한다.
- 안내 문구는 경로 진행 비율에 따른 참고 안내다. 정밀한 교차로별 내비게이션이나 안전 보장이 아니다.

## 검증 명령

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1 -Browser -TestFiles test/platform_support_test.dart
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_web_preview.ps1 -Target lib/main_web.dart -OutputRoot D:/MungcationDev/artifacts/web-app-stabilized
```

`-Browser`는 `CHROME_EXECUTABLE` 설정을 우선 사용하고, 없으면 설치된 Edge를 사용한다. 실행기는 영문 임시 경로에 사본을 남긴다. 기본 웹 빌드 명령은 계속 UI 미리보기를 생성하며, 실제 앱은 `-Target lib/main_web.dart`로 명시한다.

외부 링크 구현 근거: [Dart 공식 JavaScript interop 안내](https://dart.dev/interop/js-interop/start). 네이티브와 웹 코드를 조건부 export로 분리한다.
