# 원작 영상·소리 확인 계획과 탐색 위치

[목록](README.md) · [구조화 계획](capture_plan.json)

## 지금 읽은 것 / 아직 안 한 것

제작자 글·포트폴리오 캡션·공식 영상 전사·독립 분석자의 챕터를 읽었다. **직접 재생, 음원 청취, 프레임별 측정은 하지 않았다.** 아래 타임코드는 저자가 제공한 설명을 따라가는 탐색 위치다. 바로 해당 UI 이벤트가 시작되는 실측 위치라고 보증하지 않는다.

| 자료 | 저자 제공 위치 | 무엇을 확인할지 |
|---|---|---|
| [Greg Lester 분석](https://www.youtube.com/watch?v=kbjYl8m5cOI&t=193) | 03:13–04:20 | 메뉴/법률서의 음색과 반복 피로; 원작 청취 해석 |
| [같은 영상](https://www.youtube.com/watch?v=kbjYl8m5cOI&t=360) | 06:00–07:03 | 분석자가 나눈 음향층 |
| [같은 영상](https://www.youtube.com/watch?v=kbjYl8m5cOI&t=424) | 07:04–09:13 | 분석자 자신의 재제작 공정; 원작 제작사의 공정 아님 |
| [같은 영상](https://www.youtube.com/watch?v=kbjYl8m5cOI&t=554) | 09:14–10:26 | 법 제정 종/근무 나팔의 알림 사례 |
| [Babis VFX Reel](https://barbabis.artstation.com/projects/x3reN1) | 00:54–01:00 | Idea Tree; shader credit Marin Zujic |
| [FP2 Sounds of Frostland](https://www.youtube.com/watch?v=eiBF2uBHwas) | 타임코드 미확보 | 음향팀의 의회 군중·도시 레이어 설명 |
| [Council splotch](https://gunzes.artstation.com/projects/kNVK9d) | 페이지의 저/고 긴장·투표 캡션 | 실제 경계 움직임/합성 순서를 다음 재생에서 비교 |

## 꼭 따로 기록할 여섯 묶음

FP1 법률서, FP1 연구, FP2 Council, FP2 Idea Tree, FP2 작은 창/퀘스트, TWOM 생존자·제작·거래·일일 전환을 분리한다. 게임·빌드·플랫폼이 다른 자료를 한 클립처럼 이어 붙이지 않는다. console radial의 기능을 PC 버튼 관찰 기록에 섞지 않는다.

각 상황은 기본→focus→press→release→승인/실패→정착→닫기 순서로 기록한다. 영상 전체 길이만 적는 대신 실제 입력 전후와 해당 시간 범위를 남긴다. 버튼의 위치·모양, 범위가 커지는 방향, 글자 표시 시점, 움직임 중 재입력 가능 여부, 효과가 지속 상태인지 한 번 재생인지도 구분한다.

소리는 가능하면 음악/대사/환경을 구분해 듣되, 원본을 분리했다고 판단할 수 없는 녹음에서는 추정으로 남긴다. 화면 효과만 보고 물소리라 추정하지 않는다. 입력 시점과 소리 onset 차이, tail, 중첩, 반복/닫기/취소음을 기록한다. 직접 녹음/캡처의 배포 권리는 별도이고 공개 GitHub에 자동 업로드하지 않는다.

## 관찰 양식

recording_url, game, build, platform, language, input_method, scene_state, event, timestamp_start/end, fps_if_known, observed_visual, observed_audio, confidence, ambiguity, permission_for_redistribution, analyst, checked_at을 남긴다.

지금 recording_url/build/timestamp가 비어 있는 여섯 레코드는 **후속 조사 계획**이다. G03/G10의 저자 제공 시간대 외에는 임의의 타임코드를 채우지 않았다. 시청·청취를 하지 않은 상태에서 observed_audio 항목을 작성하지 않는다.

## 접근 한계

ArtStation 일부 페이지는 기본 웹 도구에서 오류가 났고, 직접 공개 JSON/프로필 요청은 403이었다. 기존에 반환된 Exa 본문/캡션을 사용했다. 로그인·쿠키·보안 우회는 시도하지 않았다. GIC 슬라이드 파일과 Wix 개별 프로젝트는 미확보 경로로 따로 남겼다.

영상의 자동 전사는 고유명사와 일부 단어에 오류가 있다. 짧은 제작 의도 요약에만 활용했으며 전사 전체를 저장하지 않았다. 화면의 움직임과 소리를 실제로 본 것처럼 해석하지 않았다.
