# Android 구현 및 검증

버전: 0.4.0+4. Android applicationId: `com.mungcation.mungcation`.
Flutter 3.41.9 / Dart 3.11.5, Android 최소 API 24, compile/target API 36.

## 연결한 기능

- 지도: flutter_map + OpenStreetMap XYZ 타일. 실제 위치·장소 핀·기록 경로·발자국·도보 경로, 중단 구간 분리, 화면 내 출처 표시 및 오류 재시도.
- 검색: 사용자가 실행한 검색만 Nominatim으로 전송. 자동 완성이나 일괄 수집 없음. 주변 분류 검색에는 실제 현재 위치가 필요하며 지역명을 직접 입력할 수도 있음. 공원 보상은 지도 분류가 leisure/park인 경우에만 후보로 인정.
- 길찾기: FOSSGIS의 전용 `routed-foot` OSRM 서버. 실제 좌표·거리·시간·경로를 사용하며 실패 시 경로를 만들어 내지 않음. 인도 정보와 반려동물 동반 정책은 미확인으로 표시.
- 위치: geolocator, 사용자가 동의한 산책에서만 위치 구독. 기본적으로 앱을 벗어나면 일시정지. 잠금 화면 기록을 켜면 알림 권한과 위치 foreground service를 사용하고 한국어 진행 알림을 표시. 항상 허용 위치 권한은 요청하지 않음.
- 사진: 카메라/사진 선택, 로컬 픽셀 필터, Android가 사진 선택 중 프로세스를 종료한 경우 잃어버린 결과 복구. 실제 AI 생성 서버는 연결하지 않음.
- 백업: Android Storage Access Framework 문서 생성·열기로 JSON 백업과 GPX 저장. 파일 쓰기 완료 후 성공 처리. 가져오기는 최대 32MB로 제한하고 기존 복원 검증을 적용. 전체 저장소 접근 권한 없음.
- 리소스: 픽셀 강아지 런처 아이콘 5개 밀도, adaptive icon, Android 12+ 시작 화면, 산책 알림 아이콘. 시스템 클라우드 백업은 사진·위치 정보 유출을 막기 위해 비활성화.

## 공개 지도 서버의 범위

기본 주소는 개인 개발 확인을 위한 공개 OSM 타일/Nominatim/FOSSGIS 서비스다. 검색과 경로는 앱을 식별하는 User-Agent, 직렬 요청, 최소 1.1초 간격, 10분 결과 캐시를 사용한다. 지도 타일은 flutter_map의 HTTP 헤더 기반 디스크 캐시(64MB)를 사용하며 타일 미리 가져오기는 하지 않는다. 마이 → 지도 서비스 설정에서 서버와 출처를 교체할 수 있다.

Nominatim의 초당 1회 제한은 서비스 전체 사용자 합계에 적용되므로 기기별 제한만으로 공개 출시를 충족하지 못한다. 실제 배포 전에는 자체/계약 서버로 교체하고 전체 요청량과 공급자 약관을 관리해야 한다. 좌표와 검색어는 선택한 지도 공급자에게 전달되며 공급자가 로그를 보관할 수 있다.

공식 정책: https://operations.osmfoundation.org/policies/tiles/ · https://operations.osmfoundation.org/policies/nominatim/ · https://routing.openstreetmap.de/about.html

## Windows 환경과 빌드

사용자의 SDK 설치 및 라이선스 동의 승인을 받아 설치한다. C 드라이브 여유 공간 부족으로 `D:\MungcationDev\Android\Sdk`를 사용한다. 필요한 패키지는 platform-tools, android-35/36, build-tools 35.0.0/36.0.0, NDK 28.2.13676358, CMake 3.22.1이다. Java 23을 사용하며 앱 바이트코드 대상은 Java 17이다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/install_android_sdk.ps1 -SdkRoot D:\MungcationDev\Android\Sdk -AcceptSdkLicenses
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_android.ps1 -SdkRoot D:\MungcationDev\Android\Sdk
```

빌드 스크립트는 SDK와 같은 드라이브의 ASCII 경로에 프로젝트 사본과 Gradle/Pub 캐시를 만들고, 성공 시 원본 프로젝트의 `artifacts/android/app-debug.apk`로 복사한다. 진단을 위해 작업 폴더를 유지한다. Windows의 한글 사용자 폴더 및 드라이브 간 Kotlin 캐시 오류를 피하려고 Pub 캐시도 같은 영문 드라이브 경로를 사용하며 Kotlin 증분 컴파일을 비활성화한다([Kotlin 공식 설정 문서](https://kotlinlang.org/docs/gradle-compilation-and-caches.html#incremental-compilation)). APK는 개발용 debug 서명이다. Play Store용 keystore·서명·계정·업로드는 설정하지 않았다.

## 확인 결과

- Dart 정적 분석: 오류 없음.
- 기존 및 Android 테스트 49개 통과, 추가한 Android 사진 복구 테스트 1개 통과(Android 지도 위젯/서비스/설정/파일 채널과 기존 iOS bridge·산책·백업·UI 회귀 포함).
- Android 아이콘을 포함한 브랜드 리소스 생성 테스트 4개 통과.
- 공개된 고정 서울 좌표로 FOSSGIS 도보 서버가 실제 경로 497.3m를 반환하는 것을 확인. 실제 GPS 측정 정확도 검증은 아님.
- APK 빌드: 성공(최종 Gradle assembleDebug 493.2초). Android MainActivity 및 모든 플러그인 컴파일 완료. 일부 의존성의 Java 8/deprecated API 경고는 남아 있으나 빌드 오류는 없음.
- APK 최종 위치: `D:\MungcationDev\artifacts\android\app-debug.apk` (159,601,850 bytes). C 드라이브 복사에서 공간 부족 오류가 발생하여 D 드라이브에 보관. 스크립트도 복사 실패 시 D 드라이브 대체 저장을 지원하도록 수정.
- 출시용 빌드는 개발용 debug 키를 재사용하지 않는다. Codemagic의 `CM_KEYSTORE_*` 변수 또는 Git에서 제외된 `android/key.properties`에 실제 업로드 키가 있어야 서명된다.
- Android apksigner 검증: 성공, APK Signature Scheme v2, 서명자 1개.
- SHA-256: `B249048979FDD82FB549F5D69FC48D7706001083E260629877D769A0D94D82B2`.
- 병합된 manifest에서 위치 foreground service 타입과 알림 권한, 시스템 백업 비활성화 확인. 항상 허용 위치/전체 저장소/사진 라이브러리 읽기 권한은 추가되지 않음.
- Android 실제 기기/에뮬레이터 UI·GPS·백그라운드 검증은 아직 수행하지 않음. iOS Swift 컴파일과 iPhone 검증도 Mac에서 별도 필요.

## 기기에서 확인할 항목

1. 최초 실행, 한국어 UI, 사진·카메라 권한 허용/거부와 사진 복구.
2. 위치 권한 거부·대략적 위치·GPS 꺼짐·통신 끊김 처리.
3. 실제 100m/60초 이상 걷기, 일시정지 후 재개, 앱 재실행 복구, 거리와 공원 체류 보상.
4. 기본 앱 이탈 자동 정지와 별도 잠금 화면 기록 옵션, 알림 거부, 화면 잠금, OEM 배터리 절약, 종료 후 위치 알림 해제. 강제 종료 후 기록 지속은 보장하지 않음.
5. 지도 이동/확대, 장소 핀 선택, 외부 지도 열기, 검색 오류와 도보 경로 부재, 출처 링크.
6. JSON/GPX 문서 저장 취소·성공, 백업 복원 취소·손상 파일·용량 초과, 저장 실패 시 기존 상태 유지.
7. 앱 제거 전 백업: 앱 삭제 시 로컬 사진과 산책 기록도 삭제됨.
