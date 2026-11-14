# 멍케이션 — iOS · Android Flutter 앱

기존 픽셀 강아지 방과 UI를 유지하면서 실제 산책·사진·장소 검색·보상·꾸미기·기록과 백업을 연결했습니다. 버전은 `0.4.0+4`이며 Android 실행 프로젝트도 포함합니다.

## Android 실행

Android 지도·검색·도보 경로, GPS 기록과 선택형 잠금 화면 기록, 사진 복구, 백업/GPX 문서 저장을 연결했습니다. iOS는 기존 MapKit을 사용합니다.

C 드라이브 공간 부족으로 이 노트북의 SDK는 `D:\MungcationDev\Android\Sdk`에 설치합니다. 다음 명령은 한글 경로 문제를 피하도록 D 드라이브의 사본에서 빌드하고 성공 시 `artifacts/android/app-debug.apk`로 복사하며, 프로젝트 드라이브의 복사가 실패하면 빌드 드라이브의 `artifacts/android`로 저장합니다. 이번에 생성한 APK는 **`D:\MungcationDev\artifacts\android\app-debug.apk`**에 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_android.ps1 -SdkRoot D:\MungcationDev\Android\Sdk
```

Android 휴대폰으로 APK를 복사해 설치하거나 USB 디버깅 연결 후 다음 명령을 실행하세요.

```powershell
& 'D:\MungcationDev\Android\Sdk\platform-tools\adb.exe' install -r 'D:\MungcationDev\artifacts\android\app-debug.apk'
```

 APK는 iPhone에 설치할 수 없습니다. 에뮬레이터는 Android Studio에서 별도 설치해야 합니다.

마이 → 지도 서비스 설정에서 타일·검색·도보 서버와 출처를 바꿀 수 있습니다. 기본 공개 서버는 개인 개발 확인용입니다. 여러 사용자에게 배포하기 전에는 서비스 전체 요청량을 관리하는 자체/계약 공급자로 전환해야 합니다.

검증 범위와 기기 점검 항목: [Android 검증 문서](docs/ANDROID_VALIDATION.md).

배포 전 파일·버전·iOS 프로젝트 참조·서명 자료 유입 여부를 확인하려면 다음을 실행한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/preflight.ps1
```

현재 데이터 처리 방식과 스토어 제출 전 채울 항목은 [개인정보 처리 안내 초안](PRIVACY.md)에 정리되어 있다.

현재 완료 상태와 계정 연결 후 남은 작업은 [출시 준비 체크리스트](docs/RELEASE_CHECKLIST.md)에서 확인할 수 있다.

## Windows에서 iPhone으로 현재 화면 확인

운영 코드는 계속 Flutter로 유지한다. Expo Go용 React Native 사본 대신 Flutter 웹 미리보기를 같은 저장소에 추가했으므로 픽셀 방과 꾸미기 UI를 운영 코드와 함께 관리할 수 있다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/run_web_preview.ps1
```

출력된 주소를 같은 Wi-Fi의 iPhone Safari에서 연다. GPS·카메라·MapKit·파일 공유·백그라운드 위치는 실제 iOS 앱과 같지 않으므로 미리보기에서 별도로 표시한다. 실제 기능은 Codemagic의 unsigned iOS 검증 후 TestFlight에서 확인한다. 자세한 순서는 [웹 미리보기와 TestFlight 안내](docs/WEB_PREVIEW.md)에 있다.

## 구현된 기능

### 0.3.0에서 추가한 사용 흐름

- **마이 → 전체 기록 · 통계 · 달력**: 최근 7일·월별·전체 기록, 날짜별 선택, 거리·시간·활동 일수 및 실제 기록 기반 주간 그래프.
- **홈 → 동반 매장 → 즐겨찾기**: 장소 저장·해제, 저장한 장소를 네트워크 검색 없이 조회·검색. 매장 상세의 **내 동반 조건 메모**는 개인이 쓴 정보로 구분하며 일반 동반 조건을 공식 확인으로 바꾸지 않음. 전화번호 복사도 제공.
- **개별 산책 결과 → 산책 경로 GPX 내보내기**: 일시정지·수신 공백 구간을 분리한 GPX 파일. 실제 이동 좌표·UTC 시각만 포함하며 지갑·사진은 포함하지 않음.
- **마이 → 백업과 복원**: 프로필·사진·지갑·장착·가구·즐겨찾기·완료된 산책을 JSON 파일 하나에 보관하고 복원. 최대 32MB. iOS 공유 시트에서 파일 앱 등으로 저장하며 백업에는 암호화되지 않은 사진과 위치 정보가 포함됨.
- **복원 보호**: 파일 형식·사진 이름·이미지 디코딩·데이터 무결성 검사, 복원 내용 미리보기 및 사용자 확인, 저장 실패 시 기존 상태·사진 유지. 성공 후 참조하지 않는 앱 내부 사진 사본 정리. 진행 중인 산책에서는 백업·복원 차단. 잠금 화면 위치 설정은 꺼진 상태로 복원.
- **오류 화면 → 백업에서 복원**: 기본 저장 파일을 읽지 못한 상태에서도 검증된 백업을 사용자 확인 후 복원 가능.
- 기존 v1·v2 저장 데이터를 읽고 즐겨찾기가 추가된 v3 스키마로 저장. 사진은 새 파일 이름으로 복원하여 현재 사진을 미리 덮어쓰지 않음.

내보낸 파일은 앱 내부 기록을 삭제해도 자동으로 삭제되지 않습니다. 파일 앱이나 공유한 서비스에서 별도로 관리해야 합니다. 백업은 사용자 소유 로컬 파일로, 서버 서명·위변조 방지나 계정 동기화를 제공하지 않습니다.

### 기존 핵심 기능

- **산책**: 동의 후 위치 권한 요청, 시작·일시정지·재개·종료, 실제 GPS 경로·거리·시간, 발자국, 개별 산책 결과.
- **기록 안정성**: 위치 정확도·시간·속도·모의 위치 필터, 90초 이상 수신 공백 및 일시정지 구간 분리, 약 10초 간격 자동 저장, 앱 재실행 시 저장된 진행 기록을 일시정지 상태로 복원.
- **백그라운드**: 기본은 앱을 벗어나면 자동 일시정지. 사용자가 마이에서 켠 경우에만 산책 중 잠금 화면 기록을 허용하도록 iOS 설정과 위치 스트림을 연결. 종료·중단 시 위치 구독 해제.
- **지도**: iOS MapKit 네이티브 지도, 현재 위치, 검색 결과 핀, 실제 기록 선·발자국, 제공 가능한 지역의 도보 경로·대안·안내 단계. 별도 지도 API 키 없음.
- **장소**: 지역·종류·검색어 검색, 실제 장소명·주소·제공되는 전화번호, Apple 지도 열기. 동반 여부·영업시간·케이지·유모차·체중 제한·메뉴 등 미확인 정보는 확인 필요로 표시.
- **사진**: 카메라·갤러리, 기기 내 파일 보관, 변경·삭제, 픽셀 필터와 방 액자 반영. 사진은 외부 서버로 보내지 않음.
- **육성**: 기본 및 갈색·크림·검정 강아지 선택, 하트·커스텀 캐릭터 점프·꼬리 반응, 실제 산책 완료 시 경험치·레벨, Lv.2 왕관 해제.
- **보상**: 유효 산책 완료 및 GPS로 확인한 공원 방문, 하루 중복 공원 보상 제한, 일일 한도, 지갑 및 적립·사용 내역.
- **꾸미기**: 리본·모자·선글라스·목걸이 레이어 동시 장착, 같은 모자 슬롯 중복 방지, 구매·해제, 화분·침대·공 구매와 드래그 배치·숨기기·저장.
- **저장**: 앱 전용 폴더의 버전 있는 JSON과 사진 파일, 파일 교체 전 flush, 쓰기 순서 직렬화, 저장 실패 시 이전 상태 유지, 이전 v1 데이터 이관. 산책별·전체 위치 기록 삭제.
- **기타**: 홈·지도·상점·마이, 오늘의 기록과 성장, 한국어 기본 대화상자·메뉴, 브랜드 앱 아이콘·시작 화면, 오픈소스 라이선스 화면.

## 현재의 경계

이 코드는 **Android·iOS 실기기 및 출시 검증 전**입니다. 작업 환경이 Windows이므로 Swift 컴파일, 네이티브 플러그인, 실제 위치·잠금 화면·카메라·MapKit 동작은 Mac + Xcode와 iPhone에서 확인해야 합니다. Dart 테스트가 이 검증을 대신하지 않습니다.

1. **AI 캐릭터 생성**: 사용자와 합의한 대로 기기 내 사진 픽셀 필터를 구현했습니다. 사진 필터는 AI 생성이나 반려견 분리·복원이 아닙니다. 실제 AI 서버는 연결하지 않았습니다.
2. **안전 우선 경로**: 인도 확인/없음 확인/미확인의 평가 엔진과 설명 화면은 구현했습니다. 현재 지도 공급자 응답에는 필요한 인도 데이터가 없어 실제 경로는 모두 미확인으로 유지하며 안전 경로 순위를 만들지 않습니다.
3. **동반 조건**: Apple 지도 검색으로 얻지 못하는 동반 규정·메뉴·대여 등은 실제 장소에 확인해야 합니다. 일반 검색 결과를 동반 가능 매장으로 확정하지 않습니다.
4. **지역별 도보 경로**: MapKit이 해당 지역의 도보 경로를 제공하지 않으면 오류·대체 안내를 표시합니다. 가상 선이나 거리를 대신 출력하지 않습니다. 한국 지도 공급자를 별도로 연결하려면 공식 SDK/API 접근 권한과 이용 조건 확인이 필요합니다.
5. **포인트**: 현금 가치 없는 기기 내 앱 포인트입니다. 서버 인증·다기기 동기화·위치 조작의 완전한 방지는 구현하지 않았습니다. 기존 데모 포인트와 데모 기록은 이관하되, 데모 기록을 실제 산책·경험치로 전환하지 않습니다.
6. **계정·동기화·배포**: 로그인, 클라우드 동기화, App Store 계정·서명·업로드는 연결하지 않았습니다. 현재 식별자는 임시 `com.mungcation.mungcation`입니다.

## 보상과 GPS 규칙

설정은 `RewardPolicy` 및 `WalkSession`에 있습니다.

- 100m 이상·60초 이상 기록된 산책 기본 20P, 기본 보상이 지급되는 산책에 경험치 20.
- Apple 지도에서 공원으로 분류된 검색 지점 반경 60m의 안쪽에서 `거리 + 위치 오차 ≤ 60m`, 오차 20m 이하인 위치가 10초 이상 확인되면 방문 인증. 위치 수신 간격이 25초 이상 벌어지면 연속 확인을 다시 시작.
- 동일 공원은 하루 한 번, 모든 산책·방문 보상 합계는 하루 최대 120P. 거리·시간을 길게 늘려도 기본 보상은 증가하지 않음.
- 위치 오차 35m 초과, 20초보다 오래된 위치, 모의 위치, 중복·역순 시각, 초속 4.5m를 넘는 급격한 이동은 제외. 작은 흔들림은 거리에서 제외.
- 개별 기록 삭제 시 당일 중복 보상을 막는 해시된 장소 ID·보상 날짜와 지갑·경험치는 남음. 전체 위치 기록 삭제에서는 장소 식별자도 삭제하고, 당일 보상 총량과 지갑·경험치만 유지.
- 공원 핀 좌표가 공원 경계 전체를 표현하지는 않습니다. 핀에 접근할 수 없는 경우 보상을 위해 진입하지 마세요.

## 실행

```sh
flutter pub get
flutter analyze
flutter test --concurrency=1
```

Mac에서 iOS 검증:

```sh
bash tool/verify_ios.sh
open -a Simulator
flutter devices
flutter run -d <iOS-device-id>
```

`verify_ios.sh`는 의존성·분석·Flutter 테스트 후 서명 없는 시뮬레이터 빌드까지 실행합니다. 코드를 업로드하거나 배포하지 않습니다. 네이티브 XCTest는 Xcode의 Runner 스킴에서 별도로 실행합니다.

실기기는 `ios/Runner.xcworkspace`를 Xcode에서 열어 Runner의 Signing & Capabilities에서 개발 팀과 고유 Bundle Identifier를 설정하세요. iOS 사용 목적 문구, Background Location 모드 및 한국어 설정은 파일에 추가했습니다. 테스트 시나리오는 [iOS 검증 문서](docs/IOS_VALIDATION.md)에 있습니다.

## 검증

- Flutter 의존성 설치 성공.
- Dart 정적 분석 및 Flutter 테스트 수행. 최종 결과는 [검증 문서](docs/IOS_VALIDATION.md)에 기록.
- GPS·보상 테스트는 제어된 위치 공급자, 지도 통신 테스트는 MethodChannel 대역을 사용합니다. 사진 픽셀 필터와 JSON 파일 저장·삭제는 실제 로컬 파일로 검증합니다.
- Windows 원래 한글 경로에서 Flutter 테스트 엔진의 `Could not prepare isolate`가 발생하여 같은 소스를 영문 임시 경로에 복사하고 TEMP/TMP를 지정해 실행했습니다.
- [꾸미기 방 렌더링](artifacts/room_preview.png)은 코드로 렌더링해 확인했습니다. 실제 iOS 지도 화면의 스크린샷은 아닙니다.

## 코드 구조

| 위치 | 역할 |
|---|---|
| `lib/main.dart` | 앱·한국어 테마·탭·홈 |
| `lib/models/` | 프로필·지갑·아이템·GPS·기록·장소·경로 |
| `lib/services/app_controller.dart` | 직렬 저장·구매·성장·보상 원장 |
| `lib/services/walk_session.dart` | 산책 수명주기·GPS 필터·복구·방문 인증 |
| `lib/services/location_source.dart` | 실제 위치와 권한, 대체 가능한 공급자 |
| `lib/services/map_service.dart` | MapKit 통신·공급자 계약·안전 평가 |
| `lib/services/local_repository.dart` | JSON 원자적 교체·v1/v2 이관 |
| `lib/services/walk_statistics.dart` | 기간·날짜별 산책 집계 |
| `lib/services/backup_service.dart` | 백업 검증·사진 복원·GPX 생성·임시 파일 정리 |
| `lib/services/file_transfer.dart` | iOS 파일 가져오기·공유 계약 |
| `lib/services/media_store.dart` | 사진 영구 보관·기기 내 픽셀 필터·삭제 |
| `lib/features/` | 등록·지도·장소·결과·상점·마이·방 배치 |
| `lib/widgets/` | 네이티브 지도·픽셀 방·아이템 레이어·사진 |
| `ios/Runner/MungcationFilesPlugin.swift` | 네이티브 공유 시트·JSON 파일 선택, 32MB 제한 |
| `ios/Runner/MungcationMapPlugin.swift` | MapKit 화면·검색·도보 경로 브리지 |
| `test/` | 로직·저장·GPS·지도 계약·화면 테스트 |
| `tool/render_brand_assets_test.dart` | 아이콘·시작 이미지·방 미리보기 재생성 |

기술 근거: [Flutter iOS 플랫폼 뷰](https://docs.flutter.dev/platform-integration/ios/platform-views), [MapKit 장소 검색](https://developer.apple.com/documentation/mapkit/mklocalsearch), [MapKit 경로](https://developer.apple.com/documentation/mapkit/mkdirections), [Geolocator iOS 설정](https://pub.dev/packages/geolocator), [사진 선택 설정](https://pub.dev/packages/image_picker).
