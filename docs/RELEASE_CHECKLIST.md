# 멍케이션 출시 준비 체크리스트

## 현재 상태

2026-11-17 소스와 로컬 검증 기준. 최신 결과는 [안정화 검증 기록](STABILIZATION_VALIDATION.md)을 우선한다.

- [x] Flutter `0.4.0+4` 공통 기능 구현
- [x] 정적 분석 통과
- [x] 최종 Flutter 자동 테스트 78개 통과
- [x] 별도 Gradle 캐시에서 Android debug APK 재빌드 성공
- [x] iPhone Safari용 Flutter 웹 미리보기 릴리스 빌드
- [x] iOS MapKit·파일 공유 Swift 브리지 및 네이티브 입력 테스트 작성
- [x] CocoaPods와 Codemagic unsigned/TestFlight 워크플로 준비
- [x] 서명 자료·환경 파일 Git 제외
- [x] 개인정보 처리 안내 초안 작성
- [x] Git 커밋 이력 및 GitHub 원격 주소 설정 확인 (원격 실행 성공과 구분)
- [x] 백업 접근·왕복 안내·웹 지원 경계 개선
- [x] PR 전체 분석·테스트·Android/웹 빌드 및 iOS 검증 워크플로 작성

## 출시 전 남은 검증·외부 연결

- [ ] 최신 변경사항 원격 CI 실행 및 성공 확인
- [ ] 실제 브라우저 UI와 Safari 위치 기능 검증
- [ ] 자체/계약 지도 공급자와 서비스 전체 요청량 관리 방식 확정
- [ ] Codemagic에 저장소 연결
- [ ] `iOS unsigned validation` 실행 및 Swift/Xcode 오류 수정
- [ ] 고유 Bundle ID 확정
- [ ] Apple Developer Program 가입
- [ ] App Store Connect 앱 레코드와 API 키 생성
- [ ] iOS 배포 인증서·프로비저닝 프로파일 연결
- [ ] `iOS TestFlight internal` 실행
- [ ] 실제 iPhone에서 GPS·카메라·MapKit·잠금 화면·백업 검증
- [ ] Android 실기기에서 같은 시나리오 검증
- [ ] 개인정보 처리방침에 운영자·문의 이메일·공개 URL 입력
- [ ] 스토어 데이터 공개 항목과 실제 앱 동작 최종 대조

## 로컬 검사 명령

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/preflight.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/run_web_preview.ps1 -SkipBuild
```

Android 개발용 APK:

```text
D:\MungcationDev\artifacts\android-stabilized\app-debug.apk
```

웹 미리보기:

```text
D:\MungcationDev\artifacts\web-preview
```

## 서명 자료 주의

`.p8`, `.p12`, `.mobileprovision`, `.jks`, `.keystore`, `key.properties`, `.env` 파일은 Git에 올리지 않는다. Android 로컬 릴리스 서명은 `android/key.properties.example`을 복사한 `android/key.properties`에서 설정한다. Codemagic에서는 비밀 환경 변수와 Code signing identities를 사용한다.
