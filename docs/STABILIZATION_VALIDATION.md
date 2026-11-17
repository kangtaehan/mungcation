# 안정화 검증 기록

검증일: 2026-11-17, Windows / Flutter 3.41.9 / Dart 3.11.5.

## 확인한 결과

- Dart 분석: `dart analyze` 전체 프로젝트 오류·경고 없음.
- 전체 Flutter 테스트: 최종 코드 78개 통과. 목적지 해제와 예약된 재탐색의 경합, 빈 귀환 경로 응답을 각각 오류 재현 후 수정했다.
- 실제 웹 앱: `lib/main_web.dart` 릴리스 빌드 성공. 로컬 미리보기 예시 진입점과 구분한다.
- Android 최종 APK: debug 빌드 및 apksigner 검증 성공, v2 서명·서명자 1개. SHA-256: `3163AFF0E9B31EA8DD1CBAC87F7CFE28B42ADB64C50762C8BF8DCB4F13D71310`.
- 산출물: `D:/MungcationDev/artifacts/android-stabilized/app-debug.apk`, `D:/MungcationDev/artifacts/web-app-stabilized`.
- 백업 화면 진입, 손상된 기본 저장소에서 복원 진입, 동일 경로 왕복, 긴 구간 투영, 원래 출발점으로 재탐색, 귀환 경로 실패 처리 회귀 테스트 포함.
- 기존 미추적 `artifacts/verification/` 이미지는 변경하지 않았다.

## 환경 문제와 검증 한계

- 샌드박스에서는 SDK 잠금 파일에 접근하지 못해 `flutter.bat`가 대기한다. 허용된 실행으로 검사했다.
- Windows 한글 경로에서는 Flutter 테스트 엔진이 `Could not prepare isolate`로 실패한다. 저장소의 `tool/test_windows.ps1`로 영문 임시 경로에서 검사했다.
- 브라우저 테스트는 SDK 사전 컴파일 실행기의 `C:\b\s\w\ir\x\w\archive\.pub-cache\...\host.dart.js` 리소스 경로 오류로 실행되지 않았다. Flutter 도구 소스 실행과 설치된 패키지 맵 명시 실행도 로딩 단계에서 완료되지 않아 중단했다. Windows 실행 스크립트에는 패키지 맵을 명시하는 우회를 남겼다. 테스트를 삭제하거나 건너뛰도록 변경하지 않았다. PR의 Linux Chrome 검사에서 별도로 확인해야 한다.
- 브라우저 UI 도구는 접근 승인 시간 초과로 화면 검증을 완료하지 못했다. 웹 빌드 성공은 실제 Safari·Edge UI 검증을 대신하지 않는다.
- Android 최초 재빌드는 기존 Gradle 변환 캐시를 stat 하는 단계에서 실패했다. AGP는 8.11.1이며 도구의 AGP 9 안내만 보고 버전을 변경하지 않았다. 별도 `-GradleCacheRoot`로 공유 캐시를 보존한 재빌드에 성공했다. 산출물은 `D:/MungcationDev/artifacts/android-stabilized/app-debug.apk`다.
- iOS Swift 컴파일·XCTest·시뮬레이터는 Windows에서 실행할 수 없다. 추가한 macOS PR 워크플로는 아직 원격 실행하지 않았다.
- Android/iPhone 실기기의 GPS·잠금 화면·배터리·카메라·문서 선택은 미검증이다.
- Android SDK XML 버전·일부 플러그인의 Java 8/deprecated API 경고와 웹 CupertinoIcons 글꼴 경고는 남아 있다. 컴파일·패키징은 성공했으며 실제 화면에서 글리프와 기기 동작을 추가 확인해야 한다.

## 재현

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1 -TestFiles test/walking_reroute_test.dart
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1 -Browser -TestFiles test/platform_support_test.dart
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_android.ps1 -SdkRoot D:/MungcationDev/Android/Sdk -OutputRoot D:/MungcationDev/artifacts/android-stabilized -GradleCacheRoot D:/MungcationDev/Builds/gradle-cache-stabilized
```

계정 생성·유료 지도 공급자 계약·스토어 배포 서명·업로드는 수행하지 않았다. APK는 개발용 debug 서명이다.

## 적용한 Agent Skills

- `using-agent-skills`, `planning-and-task-breakdown`: 범위·순서·완료 기준.
- `git-workflow-and-versioning`, `incremental-implementation`: 작업 브랜치와 단계별 변경.
- `test-driven-development`, `debugging-and-error-recovery`: 회귀 재현과 SDK·캐시 원인 확인. 복잡한 길안내의 재현 테스트는 별도 에이전트가 작성했다.
- `code-review-and-quality`, `code-simplification`: 호출 경로 검토와 화면 책임 분리.
- `frontend-ui-engineering`: 기존 UI를 유지한 플랫폼 제한·사용자 안내.
- `ci-cd-and-automation`, `documentation-and-adrs`: PR 검사·빌드와 지원표·검증 문서.
- `browser-testing-with-devtools`, `computer-use`: 브라우저 검증 경로 확인. DevTools 연결 도구 부재와 앱 접근 승인 시간 초과로 직접 화면 검증은 완료하지 못했다.
