# 이동 사건 batch01 초안

상태: 초안 작성 및 필수 검증 완료. 전송·제출 없음.

## 범위와 가정

- 기준 HEAD: 3e98afc7690d2528ade24009f7ff472dac380f59. 실제 가지는 research/codex-events-20261009이며, 요청의 claude/events-choices-ixln5m와 이름이 다르다. 커밋이 같아 현재 사본에서 진행했다. git 쓰기 없음.
- 20장: 사건사고 8(초기 5 + 지연 후속 3), 선로 4, 숨 쉬는 사건 5, 처지 3. 화부 화상은 발주 분류대로 처지 사건이다.
- 모든 카드는 travel/s1a, repeat 0. 특정 인물 상태·외부 기록 id를 만들지 않으며 witnesses는 빈 배열이다. 구조 키와 식별자는 저장소 계약대로 영문, 본문과 대사는 한국어다.
- 값을 치른다/한 칸에 떠넘긴다를 기본으로 한다. 작은 사고 3장에만 미루기를 더한다. 선로 장애는 현장에서 해결하도록 두 선택지다.
- choices.followups는 현재 엔진에서 즉시 호출이므로 빈 배열. 지연 후속은 effects의 flag + followup(delay 2/3/4)로 예약한다. 발주의 followups를 기존 지연 호출 기능으로 해석했다.
- 후속 trigger는 구간 3~24 및 해당 pending=false. flag는 예약 전 undefined, 예약 중 true여서 자연 추첨을 막는다. 예약 호출은 현재 addContentCard가 trigger를 검사하지 않는 동작으로 표시한다. 두 후속 선택지가 pending을 false로 지우고, 처리 뒤 재추첨은 repeat 0이 막는다. 실제 엔진 검사 대상이다.
- S1a의 24구간을 범위 상한으로 삼고, 초기 사건은 늦어도 18구간에 배치해 후속이 런 안에 오게 했다. 수치는 자원 2~8, 관계 3~8, 노출 증가 4~10. 숨 쉬는 사건에도 작은 비용을 둔다.
- production-intake-router로 범위를 확인했다. 작업 게시판 쓰기는 allowlist 밖이므로 미실행(F-WRITE-SCOPE). 역사·장소 조사, 인터넷, 외부 모델, 설치, GUI 없음.

## 사건별 점검

| id | 종류 | 조건 | 선택지 요약 | 금지선 점검 |
|---|---|---|---|---|
| ev_b01_frayed_strap | 사건사고 | 2~18구간 | 끈을 갈아 준다（luxury -2, engine relation +3） / 앞칸에 받침을 맡긴다（front community.crowding +4, front relation -3） / 매듭만 보탠다（engine relation -3, b01_strap_pending=true, ev_b01_strap_break 2구간 뒤 호출） | 통과: 짐은 나무 상자. 집단 낙인·상해 장면 없음 |
| ev_b01_sack_seam | 사건사고 | 3~18구간 | 자루를 꿰맨다（luxury -2, food -2） / 꼬리칸에 정리를 맡긴다（tail community.ration -4, tail relation -3） / 받침만 대 둔다（food -2, b01_sack_pending=true, ev_b01_scattered_grain 3구간 뒤 호출） | 통과: 도난·범인·늦게 탄 사람 없음. 자루 파손 손실 |
| ev_b01_wobbly_cart | 사건사고 | 4~20구간, 앞칸 과밀 ≥55 | 바퀴를 손본다（luxury -3, front relation +3） / 기관실이 나눠 든다（engine community.exposure +4, engine relation -4） | 통과: 객차 안 상자 운반. 감금·강제 이송·다친 몸 묘사 없음 |
| ev_b01_lamp_glass | 사건사고 | 2~20구간 | 등의 유리를 갈아 준다（luxury -2, front relation +3） / 앞칸 등을 빌린다（front relation -3, trust -2） | 통과: 유리 파손만. 누유·화재·폭발 없음 |
| ev_b01_cracked_handle | 사건사고 | 3~18구간 | 자루를 새로 깎는다（luxury -3, engine relation +3） / 경비칸 공구를 빌린다（guard relation -4, guard community.exposure +4） / 자루에 천을 감는다（luxury -2, b01_handle_pending=true, ev_b01_handle_break 4구간 뒤 호출） | 통과: 도구 마모. 무기·제복·폭발 없음 |
| ev_b01_strap_break | 사건사고 | 끈 보강 선택 2구간 뒤 예약 호출; 자연추첨 차단 flag | 끈과 받침을 바꾼다（luxury -4, food -2, b01_strap_pending=false） / 앞칸에 짐을 나눈다（front community.crowding +6, front relation -5, b01_strap_pending=false） | 통과: 초기 끈의 물건 파손 후속. 상자만, 사람 피해 없음 |
| ev_b01_scattered_grain | 사건사고 | 자루 받침 선택 3구간 뒤 예약 호출; 자연추첨 차단 flag | 남은 식량으로 메운다（food -6, trust -2, b01_sack_pending=false） / 꼬리칸 몫을 줄인다（tail community.ration -6, tail relation -5, b01_sack_pending=false） | 통과: 파손·젖은 바닥이 원인. 병·도난·집단 탓 없음 |
| ev_b01_handle_break | 사건사고 | 자루 감기 선택 4구간 뒤 예약 호출; 자연추첨 차단 flag | 새 망치를 꺼낸다（luxury -5, coal -2, b01_handle_pending=false） / 경비칸에 수리를 맡긴다（guard community.exposure +6, guard relation -5, b01_handle_pending=false） | 통과: 도구 파손과 작업 지연. 화재·폭발·군복·상해 묘사 없음 |
| ev_b01_fallen_tree | 선로 사건 | 3~20구간 | 작업조 식량을 낸다（food -4, coal -2） / 앞칸에 벌목을 맡긴다（front community.exposure +6, front relation -4） | 통과: 이름 없는 숲. 폭약·화재·연기·아이 작업 없음 |
| ev_b01_two_wagons | 선로 사건 | 4~20구간 | 화차를 측선으로 옮긴다（coal -6, food -2） / 경비칸에 밀기를 맡긴다（guard community.exposure +8, guard relation -5） | 통과: 화차는 처음부터 문 열림·빈 내부. 문 닫는 동작·사람·시신·짐 더미 없음 |
| ev_b01_doubtful_bridge | 선로 사건 | 5~20구간 | 다리 받침을 보강한다（luxury -4, coal -3） / 기관실에 보강을 맡긴다（engine community.exposure +8, engine relation -5） | 통과: 이름 없는 작은 골짜기. 실제 강·지명·연기·폭발 없음 |
| ev_b01_frozen_switch | 선로 사건 | 3~20구간 | 분기기 얼음을 걷는다（food -3, coal -2） / 경비칸에 얼음을 맡긴다（guard community.exposure +6, guard relation -4） | 통과: 분기기 정비로 기존 급수탑 결빙·눈더미와 구별. 불·폭약·지명 없음 |
| ev_b01_warm_potatoes | 숨 쉬는 사건 | 2~20구간 | 감자를 조금씩 나눈다（food -2, tension -3） / 앞칸 몫에서 나눈다（front community.ration -2, front relation -3, tension -3） | 통과: 좋은 음식 장면. 배급 줄·기존 탄수차 채집과 다름. 집단 비난 없음 |
| ev_b01_frost_bird | 숨 쉬는 사건 | 2~20구간, 꼬리칸 온기 ≤55 | 다른 창에도 그린다（luxury -2, tension -3） / 앞칸 창을 그림에 내준다（front relation -3, tension -3） | 통과: 자발적 놀이. 줄 세우기·무장 감시·호루라기·아이 작업 없음 |
| ev_b01_mended_harmonica | 숨 쉬는 사건 | 3~20구간 | 하모니카를 마저 고친다（luxury -2, tension -4） / 앞칸 헝겊을 받는다（front relation -3, tension -4） | 통과: 새로 쓴 물건과 행동. 기존 게임 대사 전재 없음 |
| ev_b01_uneven_mittens | 숨 쉬는 사건 | 4~20구간 | 실을 보태 다시 뜬다（luxury -2, front relation +3） / 꼬리칸에 풀기를 맡긴다（tail relation -3, tension -3） | 통과: 만든 사람이 먼저 웃는 실수. 집단·장애 조롱 없음 |
| ev_b01_paper_puppet | 숨 쉬는 사건 | 3~20구간 | 종이 새를 더 접는다（luxury -2, tension -3） / 앞칸 종이를 받는다（front relation -3, tension -3） | 통과: 사람과 종이의 장난. 실제 지명·타 게임 대사·낙인 없음 |
| ev_b01_full_infirmary | 처지 사건 | 2~20구간, 의무칸 과밀 ≥70 | 다른 객차에 자리를 편다（luxury -4, medtech community.crowding -6, medtech relation +3） / 앞칸에 자리를 부탁한다（front community.crowding +5, front relation -4, medtech community.crowding -5） | 통과: 병의 발생원 서술 없음. 자발적 이동, 칸 폐쇄·잠금·화차 수용 없음 |
| ev_b01_window_ice | 처지 사건 | 3~20구간, 앞칸 온기 ≤42 | 창틈을 덧댄다（luxury -3, coal -2, front community.warmth +5） / 기관실 천을 빌린다（engine community.warmth -4, engine relation -4, front community.warmth +4） | 통과: 창틈 수선으로 기존 난로 꺼짐과 구별. 병·집단 원인화·문 닫기 없음 |
| ev_b01_stoker_burn | 처지 사건 | 3~20구간, 기관실 과밀 ≥60 | 약을 쓰고 교대한다（medicine -3, coal -2, engine relation +4） / 경비칸에 보조를 맡긴다（guard community.exposure +6, guard relation -4, engine relation +3） | 통과: 뜨거운 손잡이 접촉만. 화재·폭발·상처 상세·동상 재사용 없음 |

## 열린 위험

- 수리재·천·종이·실 소모는 새 효과를 만들지 않고 현재 luxury(사치품) 자원으로 환산했다. 세부 물건별 재고는 구현하지 않은 초안 가정이다.
- 후속의 조기 자연추첨 차단은 현재 flag 비교와 예약 호출 계약에 의존한다. 엔진 변경 시 이 계약을 함께 재검사해야 한다.
- tools/content_fs.ts 기본 로더는 data/events 바로 아래 파일만 읽는다. batch01을 기본 게임에 자동 편입한 상태라고 주장하지 않는다. 편입 코드 변경은 이번 allowlist 밖이다.
- 수치와 발생 범위는 초안이며 플레이 균형·화면 렌더는 미확인. 실제 지명과 역사 조사 없이 사용자 금지선만 적용했다.

## validate 실제 결과

명령: s1에서 npm run validate -- data/events/batch01

exit_code: 0

실제 출력:

```text

> s1-content-tools@0.1.0 validate
> tsx tools/validate.ts data/events/batch01

검사 20파일 / 20항목: 오류 0개, 경고 0개
```

마지막 줄: 검사 20파일 / 20항목: 오류 0개, 경고 0개

## 추가 검사 실행 경로

- 최초 tsx 엔진 검사: exit 1, esbuild 하위 프로세스 spawn EPERM. failure_code F-CAPABILITY-ESBUILD. 권한 상승·재시도 없음.
- 설치된 TypeScript는 예상 lib/typescript.js 경로가 없어 해당 컴파일 경로는 not_run. 대안은 Node 24 내장 타입 변환과 메모리 로더이며 자식 프로세스·디스크 변환물 없이 기존 소스를 실행한다.

## 추가 실제 검증

- PASS: JSON 20개, 종류 8/4/5/3, 선택지 43개 모두 비용 있음, 행동 최대 13자, 대사 최대 29자, 수치·id·메모 검사 통과; 실제 엔진 후속 2/3/4구간 × 두 처리 선택지 = 6건 통과
- 명령: Node 24 stdin 검사. 내장 타입 변환으로 기존 엔진 소스를 메모리에서 실행. 검사용 파일·영구 테스트 생성 없음.
- 예약 전/대기 중 조기 자연추첨 없음, 기한 전 카드 없음, 기한에 정확히 한 장, 두 처리 선택지의 flag 해제, 처리 후 반복·중복 없음을 확인했다.

## 최종 result

- changed_files: s1/data/events/batch01/*.json 20개와 events_batch01_notes.md 1개, 합계 21개 신규 파일. 기존 추적 파일 변경 없음.
- verification: 지정 validate exit 0, 마지막 줄 "검사 20파일 / 20항목: 오류 0개, 경고 0개". JSON 실재·개수·고유 id·기존 id 비충돌·분류·구간 조건·선택지 비용·문자 수·수치·후속 참조 검사 통과.
- 금지선: 실제 저장된 20장 본문을 읽어 검토했으며 선택지까지 금지 표현 보조 검사 일치 0개. 화차는 처음부터 열린 빈 화차, 짐은 자루와 나무 상자, 아이는 자발적 놀이로 썼다. 병·도난·소문·실제 지명·민족·종교·제복·감금·화재·폭발을 쓰지 않았다. 기존 이동 사건 9종과 사건 소재를 대조했다.
- engine_check: Node 24 내장 타입 변환으로 실제 엔진 후속 6건 통과. 테스트 프로세스 PID 54880의 종료를 후속 조회로 확인했다. validate와 검사 명령 모두 도구에서 최종 exit_code를 받았고 진행 중 세션·백그라운드 작업 없음.
- allowlist: git status 읽기 전용 조회에서 신규 21개가 모두 허용 경로인 것을 실제 확인. git 쓰기 명령 없음.
- failure_code: 산출물/필수 검증은 none. F-CAPABILITY-ESBUILD: 최초 tsx 엔진 검사 spawn EPERM, exit 1. 다른 로컬 실행 경로로 검사를 완료했으나 tsx 경로 자체는 막힌 상태. F-WRITE-SCOPE: 작업 게시판 쓰기 미실행. F-PROBE-INPUT: 준비 중 Node -e 인용과 Windows rg 와일드카드 입력 오류가 있었으며, stdin 전달 및 명시 파일 경로로 바꿨다. 산출물 작성에는 영향 없음.
- blocked_reason: 필수 산출물 없음. 기본 게임 자동 편입과 게시판 쓰기는 allowlist 밖이므로 미실행.
- not_run: 전체 npm test·build(문안 변경에 필요하지 않음), GUI/render/live check(사용자 금지 및 초안 범위). 실제 플레이 균형은 not_verified.
- open_risks: 실제 가지명 차이, choices.followups 대신 지연 followup 효과 사용, pending=false 자연추첨 차단 계약, luxury 자원 환산, 기본 로더가 batch01을 자동으로 읽지 않는 점, 수치 균형·시각 확인 미실시.
- next_step: 20장 초안의 문안과 수치를 검토한다.

## JSON 파일 SHA-256

- ev_b01_cracked_handle.json: `7bcfcd4c7c8daaeed600dc610d1b5eea05c94c43a136d238a5dc0136e7c70d92`
- ev_b01_doubtful_bridge.json: `d5ae8ff8272178db17f2e5b686fd7429aa0a09e1255d3776c5b42b813c606a33`
- ev_b01_fallen_tree.json: `6de7e9da03507be99ef5669729efb0de485f4ca9d1e13eb14a82d985e511f1f5`
- ev_b01_frayed_strap.json: `26c441cdf6ad209d9ae7e443d24671e776369002f1b3e7b84963f1101f75143b`
- ev_b01_frost_bird.json: `e88910ef4418cee9477d69c861bbd4c2a2c80641511c166f585c1683a8805c45`
- ev_b01_frozen_switch.json: `c2df5dfba83c39fc5bd4d813a36c817ecd92ca635497cb64adee0f856d435c98`
- ev_b01_full_infirmary.json: `8b6eadb6297782777a80195e620e2ea215ab9f5fb69dd955a96884f08b40ec4b`
- ev_b01_handle_break.json: `c4054c24276387d55aa260c4b07745850d4a2c78547f7176b225aa042928d0a4`
- ev_b01_lamp_glass.json: `bd0ba7702aa4033f45525ab28ec459ed76881a8fb67f31a09a15bd785a1195ef`
- ev_b01_mended_harmonica.json: `8fa678f6e8eb2662d2501f51b2c288f829e1d2624c2e38cf13522f86a70114d1`
- ev_b01_paper_puppet.json: `793168f8d30dfec36b801fe394d98ce1ebef92ef8707af46af0bf3c555d6abb0`
- ev_b01_sack_seam.json: `bda6e94b1018f7d556c3efd24a480cf1c8c4cd7405dadf7394dda9c580166704`
- ev_b01_scattered_grain.json: `23d440ce5e8b6d995c42bb71177222d35110ca7868ef7aa965f2b004b3c0d37b`
- ev_b01_stoker_burn.json: `9bedbfbf9513259ce87245f9964a518955553de6439aa6d131636b02fa36255e`
- ev_b01_strap_break.json: `cd9114ec36e74f6c61453757613a1f6ab42bdd4058138a30ce29670ebf73f77d`
- ev_b01_two_wagons.json: `8b0a460e34315ce808312ae5abd6a697db492ab506836953f9ea44b86dccaa88`
- ev_b01_uneven_mittens.json: `3c0ffe073000aa0ff86d0b931299c249c06000dd4361c788d1fe4bcb6de55fe7`
- ev_b01_warm_potatoes.json: `cf906ab61fb9131fd092964d2f538011e59a56b9fe7dc949b771980a56d86726`
- ev_b01_window_ice.json: `7c9553661c9c3127315e2df3732841c32787b24ff58614ec6a6e2fb32e358625`
- ev_b01_wobbly_cart.json: `762c1276e6c40b1d33db827c4eb498505cefe9c6c6c8e3bc82441b427420717f`

## PC 세션 확인 (2026-10-10)

- 초안은 Codex가 썼고, PC 세션이 20장의 본문·대사·효과를 모두 읽었다. `npm run validate -- data/events/batch01`을 직접 다시 돌려 "검사 20파일 / 20항목: 오류 0개, 경고 0개"를 봤다.
- 금지선: 읽어서 걸린 줄 없음. 금지 낱말 검색(소독, 격리, 잠금, 빗장, 사슬, 호루라기, 군복, 연기, 폭발, 가방, 보따리, 신발, 시신, 열병, 도둑, 소문, 줄 세우기 등)도 0줄. 둘째 모델 대조는 하지 않았다.
- 후속 사건 예약(2·3·4구간 뒤)이 엔진에서 도는지는 Codex의 자체 검사 보고만 있고 PC 세션은 재현하지 않았다.
- 손볼 곳(금지선과 무관): 대사 43줄이 모두 '~해라' 꼴이라 단조롭다. 본문에 '이름 없는 숲·들판'이 글자 그대로 들어가 어색하다. 본문 끝말이 '합니다'와 '해요'로 섞여 있다. 자루·끈·종이 소모를 luxury로 환산한 것은 가정이다. 기본 로더는 batch01 폴더를 아직 읽지 않는다.
