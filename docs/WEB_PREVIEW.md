# 아이폰 Safari용 Flutter 미리보기

이 미리보기는 운영 앱과 같은 Flutter 저장소 안에서 `lib/main_preview.dart`를 진입점으로 사용한다. 픽셀 방과 꾸미기 위젯은 운영 코드와 공유하며, 장착 상태는 브라우저 저장소에 남는다.

GPS 산책, 카메라, 사진 선택, Apple MapKit, iOS 파일 공유, 백그라운드 위치는 브라우저가 실제 iOS 앱과 동일하게 제공하지 않는다. 화면에는 이 기능을 TestFlight에서 확인하라는 안내가 표시된다. 미리보기의 지도와 통계 숫자는 UI 확인용 예시다.

## 실제 웹 앱과 구분

GitHub Pages는 `lib/main_web.dart`를 빌드한다. 이 진입점은 실제 앱 화면·브라우저 저장·지도·GPS를 사용하며, 사진·백업·GPX·잠금 화면 기록은 모바일 전용으로 안내한다. 위치 기능은 HTTPS 또는 localhost와 브라우저 권한이 필요하다. 위의 UI 미리보기 예시 수치와 실제 웹 기록을 혼동하지 않는다. 자세한 기능 경계와 검증 명령은 [플랫폼 지원표](PLATFORM_SUPPORT.md)를 참고한다.

## 같은 Wi-Fi에서 아이폰으로 열기

Windows PowerShell에서 다음 명령을 실행한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/run_web_preview.ps1
```

명령이 출력한 `http://노트북-IP:8080` 주소를 같은 Wi-Fi에 연결된 iPhone Safari에서 연다. Windows 방화벽이 연결을 물으면 개인 네트워크만 허용한다. 서버를 종료하려면 터미널에서 `Ctrl+C`를 누른다.

이미 최신 빌드가 있으면 다시 빌드하지 않고 바로 열 수 있다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/run_web_preview.ps1 -SkipBuild
```

웹 빌드만 확인하려면 다음을 실행한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_web_preview.ps1
```

한글 사용자·프로젝트 경로에서 WebAssembly 호환성 검사가 멈추는 Windows 환경을 피하기 위해 영문 D 드라이브 작업 사본에서 빌드한다. 결과는 `D:\MungcationDev\artifacts\web-preview`에 저장한다.

## 실제 iOS 확인

1. 소스를 Git 저장소에 올리고 Codemagic에 연결한다.
2. 먼저 `iOS unsigned validation` 워크플로를 수동 실행해 Swift, CocoaPods, RunnerTests 및 iOS 시뮬레이터 빌드를 확인한다.
3. Apple Developer Program 가입 후 App Store Connect에 `com.mungcation.mungcation` 앱 레코드를 만든다. 다른 사람이 이미 사용한 Bundle ID라면 프로젝트와 `codemagic.yaml`을 함께 고유 값으로 바꾼다.
4. Codemagic Team integrations에 App Store Connect API 키를 `MUNGCATION_APP_STORE_CONNECT_KEY`라는 이름으로 등록한다.
5. iOS distribution certificate와 App Store provisioning profile을 등록한 뒤 `iOS TestFlight internal` 워크플로를 실행한다.

TestFlight 업로드는 Apple 계정과 서명 자료가 연결된 뒤에만 실행한다. `ios-testflight` 워크플로는 자동 트리거를 두지 않아 저장소에 코드를 올리는 것만으로 배포되지 않는다.
