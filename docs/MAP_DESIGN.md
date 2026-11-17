# 지도 중심 UI 정리

## 목적과 디자인 기준

사용자가 제공한 지도 앱 화면에서 지도 중심 구성, 떠 있는 검색창, 간결한 필터, 하단 정보 패널의 구조를 참고한다. 멍케이션의 초록색·따뜻한 중립색·픽셀 반려견을 유지하며 다른 서비스의 로고·파란색 테마·콘텐츠를 복제하지 않는다.

- 지도: 모바일에서는 화면 배경을 채우고 검색·필터와 조절 가능한 하단 정보 패널을 겹친다. 900px 이상에서는 검색·정보를 옆 패널로 배치한다.
- 정보 우선순위: 검색·주변 탐색 → 산책 시작/진행 상태 → 선택 경로 → 장소 목록 → 상세 설명. 안내는 필요한 지점에 배치하며 가짜 날씨·리뷰·인기 순위를 추가하지 않는다.
- 스타일: 초록을 행동과 선택 상태에 집중하고, 흰 표면·얇은 경계·작은 그림자·일관된 여백과 글자 굵기를 사용한다. 장식 아이콘보다 실제 지명과 행동을 먼저 읽게 한다.
- 홈·메뉴: 캐릭터 방은 유지하고 글자 크기·버튼 높이·바로가기 카드·하단 메뉴를 정리한다.
- 접근성: 320px, 390px, 1024px 및 큰 글씨에서 사용 가능해야 한다. 장소 이름 전체 표시, 권한·오류·빈 상태와 기존 산책 기능을 유지한다.

## 범위

지도 공급자는 변경하지 않는다. 인증키 없이 브이월드·카카오로 바꾸거나 가상의 도로·장소 정보를 만들지 않는다. 기존 검색·기록·즐겨찾기·보상·복구 동작은 보존한다.

## 순서와 확인

1. 지도 패널·검색·필터 레이아웃 및 작은/큰 화면 테스트.
2. 실제 산책 화면 연결과 기존 산책·긴 장소명 회귀 테스트.
3. 공통 테마·홈·하단 메뉴의 시각적 정리.
4. 전체 Dart 분석·Flutter 테스트·렌더 이미지 시각 확인·Chrome 검사·웹 배포.

검사: `dart analyze`, `powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1`.
웹 배포는 기존 GitHub Pages 워크플로를 사용한다.

## 반영 내용과 시각 확인

모바일은 18%~90% 높이의 정보 패널(기본 38%)을 제공하고, PC는 360px 정보 패널을 사용한다. 패널 손잡이는 클릭해서도 펼칠 수 있다. 지도 출처 표시는 모바일 패널의 높이에 따라 이동한다. 내 주변·공원·카페·동물병원 필터는 기존 장소 검색을 사용한다.

공통 표면·경계·글자 굵기·버튼·하단 메뉴를 정리하고 홈의 캐릭터 방은 유지했다. 기존 산책 및 장소명 표시를 포함한 로컬 테스트 87개가 통과했다. 배포 워크플로는 실제 Chrome에서도 지도 레이아웃과 긴 장소명을 검사한다.

시각 확인 이미지는 `artifacts/design/`에 생성한다. 지도 배경은 오프라인 검사 전용 도식 타일이며 실제 서비스 지도는 기존 공급자를 사용한다. Windows에서 다음 명령으로 다시 생성할 수 있다.

```powershell
$env:MUNGCATION_RENDER_DIR = Join-Path (Get-Location) 'artifacts/design'
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_windows.ps1 -TestFiles test/design_render.dart
```

사용한 Agent Skills: frontend-ui-engineering, spec-driven-development, test-driven-development, incremental-implementation, git-workflow-and-versioning, code-review-and-quality, shipping-and-launch.
