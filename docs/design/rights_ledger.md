# 권리 장부

게임 빌드, 스토어 페이지, 홍보물에 들어가는 남의 것과 생성한 것을 한 줄씩 적는 장부다. 2026-10-07에 사운드 스레드가 처음 적었다(Pro 수집 r8 2절 18번 작업). 소리·음악·폰트는 사운드 스레드가 채우고, 그림·3D는 화면과 3D 스레드가 같은 칸으로 채운다.

## 규칙

- 파일이 빌드에 들어가기 **전에** 줄을 만든다. 후보 단계에서는 2장에 두고, 빌드에 넣는 순간 1장으로 옮긴다.
- '무료로 들을 수 있다', '무료로 받을 수 있다'를 상업 이용 허락으로 적지 않는다. 라이선스 원문이나 약관을 열어 본 날짜를 적는다.
- 곡, 편곡, 녹음은 따로 적는다. 옛 노래의 곡이 공공 영역이어도 남이 만든 편곡과 녹음은 따로 권리가 있다(sound_music.md 11장).
- 구매 영수증, 약관 사본, 생성 당시의 요금제 화면은 저장소에 올리지 않는다(공개 저장소). 사용자 PC의 보관 위치만 적는다.
- 크레딧 화면과 라이선스 고지는 이 장부에서 뽑는다. 플레이 빌드를 낼 때마다 3장의 맞춰 보기를 한다.
- 받은 원본 파일은 라이선스가 재배포를 허락할 때만 저장소에 올린다.

## 칸

| 칸 | 적는 것 |
|---|---|
| 자산 | 파일이나 묶음 이름, 버전 |
| 종류 | 엔진, 폰트, 효과음, 음악(곡·편곡·녹음), AI 생성, 그림, 3D |
| 출처 | 받은 곳 링크, 만든 사람 |
| 라이선스 | 이름과 버전. 확인한 날 |
| 조건 | 출처 표시 문구, 동일조건, 개작 시 이름 제한, 재배포 금지 등 |
| 증빙 | 구매·구독 증빙의 보관 위치, 생성 당시 요금제 |
| 홍보 | 트레일러, 스크린샷, 스토어 페이지에 써도 되는지 |
| 빌드 | 어느 빌드에 들어 있나(S1a 웹, S2 Godot, 출시판) |

## 1. 지금 빌드에 들어 있는 것

| 자산 | 종류 | 출처 | 라이선스 | 조건 | 증빙 | 홍보 | 빌드 |
|---|---|---|---|---|---|---|---|
| Godot Engine 4.7.2 | 엔진 | [godotengine.org](https://godotengine.org) | MIT, 엔진에 든 제3자 구성요소 각자의 라이선스 | 출시판에 Godot 라이선스 고지와 제3자 고지를 넣는다([Complying with licenses](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)). 외부 에셋의 권리는 MIT가 풀어 주지 않는다 | 필요 없음 | 가능 | S2 |
| 시스템 폰트 | 폰트 | 기기에 깔린 글꼴(S1a CSS의 system-ui 묶음, S2 `SystemFont`) | 기기 제공 | 빌드에 글꼴 파일이 들어가지 않는다. 화면이 기기마다 다르게 보일 뿐 권리 문제는 없다 | 필요 없음 | 스크린샷은 기기 글꼴로 찍힌다 | S1a 웹, S2 |
| s2/fx 셰이더 묶음(11개와 fx_common) | 코드 | 이 저장소에서 새로 짬(셰이더와 화면 효과 스레드, 2026-10-09) | 저장소와 같음 | 남의 코드·그림 없음. 공개 셰이더를 들여오면 이 표에 따로 줄을 만든다 | 필요 없음 | 가능 | S2 |

소리와 음악 파일은 아직 어느 빌드에도 없다(2026-10-07).

### 열차 겉몸과 외부 부품 가공본 (2026-10-16)

| 자산 | 종류·출처 | 가공·반입 범위 | 증빙·권리 상태 | 빌드·홍보 |
|---|---|---|---|---|
| 열차 겉몸: `tender.glb`, `locomotive.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-16 손질: 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 열차 겉몸: `coach_worn.glb`, `coach_clean.glb`, `coach_chief.glb`, `coach_medic.glb`, `coach_glass.glb`, `freight_open.glb` | 이 저장소에서 새로 만듦(Blender 4.5 헤드리스 스크립트 `tools/blender/train_exterior.py`, 2026-10-24) | 생성 모델이 녹아내린 바퀴·창·끝단·지붕을 단순한 새 모양으로 바꿈. 외부 메시·그림 없음, 색은 스크립트가 만든 256² 칸 그림 한 장 | 남의 자원 없음. 스크립트를 다시 돌리면 같은 파일이 나온다 | 가능 |
| 열차 외부 부품: `coach_window_frame.glb`, `plank_band.glb`, `plank_patches.glb`, `coach_flue.glb`, `side_step.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-16 손질: 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |

실측 목록과 가공물 SHA-256은 `s2/game/world/train_model_catalog.json`에 둔다. 검수 보류 모델은 빌드와 공개 자산 폴더에 넣지 않았다.

### 첫 정차 소품 가공본 (2026-10-17)

| 자산 | 종류·출처 | 가공·반입 범위 | 증빙·권리 상태 | 빌드·홍보 |
|---|---|---|---|---|
| 첫 정차 소품: `sleeper_fence.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `yard_gate.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `garden_wall.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `concrete_barrier.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `plank_barricade.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `canvas_windbreak.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `dining_set.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `iron_bed.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `bookcase.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `drawer_chest_spilled.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `table_overturned.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `wardrobe.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `office_desk.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `tiled_stove.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `shop_shelf.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `toolbox.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `workbench.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `folding_workbench.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `scattered_tools.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `chopping_block.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 이하로 축소, LOD 분리(작은 물건은 LOD0만). 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `mine_track.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `hand_basket.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `arrow_set.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `crt_monitor.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `kitchen_knife.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 첫 정차 소품: `machete.glb` | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-17 자국 덮기·자세 바로잡기(색 다시 칠하기 아님) 뒤 손질(tripo_prep.py): 법선·중복점 정리, 비율 보존 크기·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소, LOD 분리. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 사람·망자 몸 43벌: `s2/models/people/<묶음>_<역할>/` (`mesh.res`, `clips.json`, `vat.bin`) | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공물만 반입, 원본 GLB와 질감 미반입. 2026-10-17 손질(tripo_prep.py): 법선·중복점 정리, 키 1.7m 맞춤·바닥 원점·방향 정렬, 삼각형 축소, 색 질감 512 축소. 그 뒤 17뼈 뼈대와 무게를 넣고 게임 굽기 도구(bake_body_cli.gd --small)로 동작을 구워 작은 형식(클립마다 8비트, 프레임 절반, 자세 모음 뺌, 15클립)으로 줄인 메시·동작 그림·동작 표만 둔다. 색 다시 칠하기 없음 | 생성 당시 유료 요금제 기록은 선정 자료에 있으나 개별 생성일·생성기 버전·입력 출처·영수증 연결은 로컬 증빙 추가 대조 필요. 계정 정보와 원본은 공개하지 않음. 이번 작업은 네트워크를 쓰지 않아 약관을 새로 확인하지 않음 | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| 사람·망자 몸 둘(운동복 망자, 재봉): `s2/models/people/n3-body_tracksuit/`, `n5-crew_seamstress/`, 산 사람 동작판 `n5-crew_seamstress_p/`(같은 재봉 몸에 사람 동작만, bake_body_cli.gd --set=person) (`mesh.res`, `clips.json`, `vat.bin`, `albedo.png`) | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공물만 반입, 원본 GLB 미반입. 43벌과 같은 손질(tripo_prep.py)과 색 손질(운동복 허벅지 상표 꼴 자국 지움, 재봉 앞섶 살색을 옷 색으로 덮음) 뒤 17뼈 뼈대와 무게, 2026-10-18 다시 굽기(누운 자세 내려앉기 고침 반영)를 작은 형식(bake_body_cli.gd --small)으로 줄였다. 2026-10-24 망자 동작 열 가지(문 두드리기·할퀴기·머리 맞음 넷·돌아봄 둘·느린 걸음 둘)를 body_bake.gd에 손수 써서 두 몸 뒤에 덧붙여 27클립이 됐다(새 외부 자료 없음, 앞 17클립은 바이트가 같음). 색 그림은 가공한 몸에서 꺼낸 512 한 장(`albedo.png`)이고 게임 셰이더가 색감을 누른다 | 43벌과 같음(개별 생성일·영수증 연결은 로컬 증빙 추가 대조 필요, 계정 정보와 원본은 공개하지 않음, 네트워크 안 씀) | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |
| Quaternius Universal Animation Library 1·2(Standard 무료판)의 동작 넷(`Pistol_Reload`, `ClimbUp_1m`, `Fixing_Kneeling`, `TreeChopping_Loop`): 산 사람 동작판 `s2/models/people/n5-crew_seamstress_p/` 28~31번으로 구워 넣음(2026-10-18 `Chest_Open`·`Hit_Knockback`을 빼고 `TreeChopping_Loop`를 더함, 같은 날 `PickUp_Table`도 뺌). 2026-10-24 손으로 쓴 동작 16개가 앞에 들어가 44~47번으로 밀림(구운 바이트는 같음) | 3D(동작) | quaternius.itch.io(Universal Animation Library, Universal Animation Library 2), Quaternius | CC0 1.0. 내려받은 zip 안 `License.txt`로 2026-10-18 확인 | 표시 의무 없음. 원본 glb는 저장소에 넣지 않고 재봉 몸에 옮겨 구운 결과만 둔다(bake_body_cli.gd --set=person) | 원본 zip은 사용자 PC `assets_raw\quaternius_ual1\`, `quaternius_ual2\`에 보관 | 가능(CC0) | S2 작업본 |
| 무기: `s2/models/weapons/` 여섯 파일(`crowbar.glb`, `axe.glb`, `pistol.glb`, `shotgun.glb`, `bow.glb`, `pipe_shotgun.glb`) | AI 생성(3D), 트리포 생성 | 결정 038에 따라 게임용 가공 GLB만 반입, 원본 미반입. 2026-10-18 손질(wpost.py): 메시·재질·색 그림 하나씩, Y 위·날 끝과 총구 +Z·원점 손잡이 가운데, 게임 길이(0.8/0.4/0.2/1.0/1.3/0.9m)로 맞춤. 색 다시 칠하기 없음 | 43벌과 같음(개별 생성일·영수증 연결은 로컬 증빙 추가 대조 필요, 계정 정보와 원본은 공개하지 않음, 네트워크 안 씀) | S2 작업본. 출시·홍보 권리의 추가 확인 필요 |

파일 목록과 크기·SHA-256은 `docs/art/props_stop01.md`에 둔다. 첫 정차 지도의 수납 자리 32곳에 가구 여덟 종(책상·선반·옷장·찬장·식탁·서랍장·침대·공구함)을 놓았다(`s2/game/world/prop_models.gd`). 나머지 열여덟 종은 아직 장면에 없다.

## 2. 후보 (아직 빌드에 없음)

### 폰트 (화면 스레드가 고르면 1장으로 옮긴다)

| 자산 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|
| Barlow Condensed | [Google Fonts 저장소의 OFL.txt](https://github.com/google/fonts/blob/main/ofl/barlowcondensed/OFL.txt) | SIL OFL 1.1 (2026-10-07 원문 확인) | 글꼴 파일만 따로 팔 수 없다. 라이선스 원문을 함께 넣는다 | 가능 |
| IBM Plex Sans KR | [Google Fonts 저장소의 OFL.txt](https://github.com/google/fonts/blob/main/ofl/ibmplexsanskr/OFL.txt) | SIL OFL 1.1, 예약 글꼴 이름 "Plex" (2026-10-07 원문 확인) | 폰 용량 때문에 한글 글자를 추려 줄인 파일(서브셋)을 만들어 넣으면 고친 판으로 볼 수 있고, 그러면 그 파일 이름에 "Plex"를 쓸 수 없다. 줄인 파일은 이름을 바꿔 넣는다 | 가능 |

### 효과음

| 자산 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|
| Kenney Interface Sounds, UI Audio, Impact Sounds | [kenney.nl](https://kenney.nl/assets/impact-sounds) | CC0 | 표시 의무 없음. 크레딧에는 넣는다 | 가능 |
| Sonniss GameAudioGDC 번들 | [gdc.sonniss.com](https://gdc.sonniss.com/) | 번들 약관(상업 이용·수정·무표기 허용, 원본 그대로 재판매 금지) | 받는 해의 약관 사본을 보관한다. 원본은 저장소에 올리지 않고 가공한 파일만 빌드에 넣는다 | 가능(약관 확인 필요) |
| Freesound 개별 파일 | [freesound.org](https://freesound.org/help/faq/) | 파일마다 다름 | CC0만 표시 없이 쓴다. CC BY는 표시 문구를 적는다. CC BY-NC는 상업 게임이라 쓰지 않는다. 녹음 속 음악·말소리도 확인한다 | 파일마다 |
| 가루눈 걷기(Vrymaa, Footsteps Snow 1) | [freesound 773736](https://freesound.org/people/Vrymaa/sounds/773736/) | CC0 (Pro 수집 r2 38번이 표기만 확인, 청취 안 함) | 쓸 때 페이지를 다시 열어 확인한다 | 가능 |
| 1월의 까마귀 경계음(XC518419) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Corvus_corone_-_Carrion_Crow_XC518419.mp3) | CC BY-SA 4.0 (r2 37번) | 기록자 표시가 필요하다. 동일조건변경허락이라 이 소리를 가공한 파일도 같은 라이선스로 풀어야 할 수 있다. 조짐 소리(sound_music.md 7.1)에 쓰려면 CC0 대체를 먼저 찾는다 | 조건부 |
| 의회 군중 재료: 웅성거림 546676, 화난 군중 395583, 야유 324893 | [Freesound](https://freesound.org/people/trezz77/sounds/546676/), [395583](https://freesound.org/people/BeeProductive/sounds/395583/), [324893](https://freesound.org/people/deleted_user_2104797/sounds/324893/) | CC0 (PR 24 r11이 표기만 확인, 청취 안 함) | 알아들리는 영어 말이 있으면 쓰지 않거나 웅얼거림으로만 쓴다(sound_music.md 8b.3) | 가능 |
| 정숙 소리 재료: 손종 204360, 금속 망치 592111 | [204360](https://freesound.org/people/SoundsExciting/sounds/204360/), [592111](https://freesound.org/people/pablodavilla/sounds/592111/) | CC0 (r11, 청취 안 함) | 쓸 때 페이지를 다시 연다 | 가능 |
| 짐 싣기 재료: 눈 발소리 559459, 석탄 넣기 386143, 증기기관차 대기·기적 686057 | [559459](https://freesound.org/people/mshahen/sounds/559459/), [386143](https://freesound.org/people/ldezem/sounds/386143/), [686057](https://freesound.org/people/relwin/sounds/686057/) | CC0 (r11, 청취 안 함) | 386143은 화덕 녹음이라 기관차 소리로 단정하지 않는다 | 가능 |
| 자루 내려놓기 458124 | [Freesound](https://freesound.org/people/JonCon_Library/sounds/458124/) | CC BY 4.0 (r11) | 만든 사람, 라이선스 링크, 고친 내역을 크레딧에 적는다 | 가능(표시 조건) |
| OpenGameArt 100 CC0 SFX | [opengameart.org](https://opengameart.org/content/100-cc0-sfx) | 이 묶음만 CC0 | OpenGameArt의 다른 자료는 조건이 다르다 | 가능 |
| 망자 신음 재료(S2 회색 상자): Zombies Sound Pack, zombie noises and moans, zombie moans | [OpenGameArt](https://opengameart.org/content/zombies-sound-pack), [ianzazz](https://opengameart.org/content/zombie-noises-and-moans), [Darsycho](https://opengameart.org/content/zombie-moans) | CC0 (2026-10-07 페이지 표기 확인, 청취 안 함) | 표시 의무 없음. 크레딧에는 넣는다. 말이 들리는 파일은 뺀다(sound_music.md 12.1) | 가능 |
| S2 필드 소리 파일(2026-10-10 받음, `s2/audio/`): 신음 `moan/moan_01~08.wav`, 무리 바탕 `horde_bed/horde_bed.wav`, 모여듦 `gather/gather.wav` | [Zombies Sound Pack](https://opengameart.org/content/zombies-sound-pack)(artisticdude)의 zombie-9, 15, 16, 17, 18, 19, 20, 21.wav | CC0 (2026-10-10 페이지 표기 확인, 청취 안 함) | 모노 22050Hz 16비트로 줄임. 바탕 둘은 이 여덟을 느리게 겹쳐 만든 파일이다. 사람 말이 들리는 파일이 있으면 뺀다 | 가능 |
| 같은 묶음: 부딪힘 `impact/`(glass_01, glass_03, slam_01, slam_04, metal_03, hit_02, wooden_01), 총 `gun/`(shot_01, shot_02) | [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx)(rubberduck) | CC0 (2026-10-10 확인, 청취 안 함) | 받은 그대로(ogg). 다만 `wooden_01`과 `shot_01`은 2026-10-11에 흠을 고쳐 모노 22050Hz 16비트 WAV로 바꿨다: `shot_01`은 앞의 빈 소리 67ms를 2ms만 남기고 잘랐고, `wooden_01`은 잘린 표본 15개를 둘레 곡선으로 메우고 가장 큰 값을 −1dB로 낮췄다(앞 빈 소리 21ms도 2ms로) | 가능 |
| 같은 묶음: 눈 발소리 `step_snow/step_snow_01~02.ogg`, 바람 `wind/wind.ogg` | [Walking on snow sound](https://opengameart.org/content/walking-on-snow-sound), [Wind](https://opengameart.org/content/wind)(둘 다 ignasd) | CC0 (2026-10-10 확인, 청취 안 함) | 받은 그대로. Freesound의 773736·559459는 받으려면 로그인이 필요해 쓰지 않았다 | 가능 |
| 같은 묶음: 기적 `whistle/whistle.wav`, 기관차 대기 `train_idle/train_idle.wav` | [Steam whistle](https://opengameart.org/content/steam-whistle)의 steamwhistle_0.wav, [Steam boiler sound loop](https://opengameart.org/content/steam-boiler-sound-loop)의 generator_loop.wav(둘 다 bart) | CC0 (2026-10-10 확인, 청취 안 함) | 모노 22050Hz로 줄임. 기관차 대기는 보일러 소리 앞 10초를 이어 붙인 대역이다(실제 기관차 녹음이 아니다). 686057은 로그인이 필요해 쓰지 않았다 | 가능 |
| S2 무전 잡음(2026-10-10 만듦): `s2/audio/radio_hiss/radio_hiss.wav`, `s2/audio/radio/radio_call.wav` | 직접 만듦(난수로 만든 잡음을 대역으로 걸러 낸 것. 녹음도 받은 파일도 쓰지 않았다) | 우리 것 | 사람 말이 없다. 모노 22050Hz 16비트, 합쳐 77KB. 아무도 들어 보지 않았다. `radio_call.wav`는 2026-10-11에 첫머리 4ms를 서서히 올리게 고쳤다(첫 표본이 0.524라 딱 소리가 날 수 있었다) | 가능 |
| S2 정차 소리(2026-10-24 만듦): 증기 열차 제동 `s2/audio/train_brake/brake.wav`(4.6초, 2.4초에 선다), 서류 펼침·접힘 `s2/audio/paper/paper_open.wav`, `paper_fold.wav` | 직접 만듦(합성 스크립트 `s2/tools/sound/synth_stop_sounds.py`. 씨앗이 정해져 있어 다시 돌리면 같은 파일이 나온다. 녹음도 받은 파일도 쓰지 않았고, 사용자가 준 참고 영상은 느낌만 참고하고 내려받지 않았다) | 우리 것 | 제동은 네 겹: 이음매를 넘는 덜컹이 점점 느려짐, 떨리며 커지다 서는 순간 아래로 꺾이는 쇳소리, 연결기 쿵 넷, 증기·공기 쉭. 가장 큰 값은 바꾸기 전 파일과 같게(0.708, −3dB) 맞춰 필드의 BRAKE_LOUD가 그대로 맞는다. 종이는 마른 딸깍 알갱이와 스침을 겹쳤고 가장 큰 값 0.35. 모노 44100Hz 16비트, 셋 합쳐 약 500KB. 작업자는 들어 보지 않았고 주파수 그림(`coord\review\정차연출_20261024\소리\brake_spectrogram.png`)만 봤다 | 가능 |
| S2 필드 소리 파일(2026-10-11 받음, `s2/audio/`, 12개 합쳐 315KB): 새 떼 `birds/birds_01.wav` | [50 Birds Fly Away(1067)](https://bigsoundbank.com/50-birds-fly-away-s1067.html)(Joseph SARDIN, BigSoundBank)의 1067.ogg | CC0 (2026-10-11 쪽 표기 「CC0 (public domain)」 확인, 청취 안 함) | 10.05초부터 2.95초를 자르고 모노 22050Hz 16비트, 가장 큰 값 −3dB. 숲 녹음이라 녹음한 사람의 발소리가 섞였는지는 들어 봐야 안다. 열두 개 모두 이름과 잰 값만 보고 골랐고 아무도 들어 보지 않았다 | 가능 |
| 같은 묶음: 펜 한 획 `pen/pen_01~03.wav` | [Pencil, signature #2(3237)](https://bigsoundbank.com/pencil-signature-2-s3237.html), [Pencil #3(3234)](https://bigsoundbank.com/pencil-3-s3234.html)(둘 다 Joseph SARDIN & Axeline T., BigSoundBank)의 3237.ogg, 3234.ogg | CC0 (2026-10-11 쪽 표기 확인, 청취 안 함) | 긴 녹음에서 한 획씩 자름: 3237의 0.66초부터 545ms와 0.20초부터 440ms, 3234의 3.51초부터 495ms. 200Hz 아래를 깎고 −6dB로 맞춤. 모노 22050Hz 16비트 | 가능 |
| 같은 묶음: 쓰러짐 네 박자 `fall_hit/`, `fall_reel/`, `fall_knee/`, `fall_land/`에 둘씩(`_01~02.wav`) | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds)의 impactPunch_medium_000, impactPunch_medium_002, impactSoft_medium_001.ogg, [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)의 cloth1~4.ogg, [75 CC0 breaking / falling / hit sfx](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx)(rubberduck)의 bfh1_hit_03, bfh1_hit_06, bfh1_hit_08.ogg, [Body Fall #1(2452)](https://bigsoundbank.com/body-fall-1-s2452.html)와 [Body Fall #2(2453)](https://bigsoundbank.com/body-fall-2-s2453.html)(Joseph SARDIN, BigSoundBank)의 2452.ogg, 2453.ogg, 그리고 필드에 이미 든 `impact/hit_02.ogg`, `step_snow/step_snow_01~02.ogg` | 모두 CC0 (2026-10-11 쪽 표기 확인, 청취 안 함) | 여러 소리를 겹쳐 만든 파일이다. 맞음: 주먹 소리에 부딪힘 둘을 겹침(320ms, −4dB). 비틀: 천 스침에 눈 발소리(320ms, −10dB). 무릎: 2452의 0.84초부터 155ms 또는 무른 부딪힘에 눈 발소리(260ms, −8dB). 바닥: 2453의 0.14초부터 620ms 또는 2452의 0.07초부터 395ms에 눈 발소리와 천(700ms, −3dB, 50Hz 아래 깎음). 눈 위에 쓰러지는 녹음을 못 찾아 타일 바닥 녹음에 눈 발소리를 겹쳤다. 모노 22050Hz 16비트. 코드가 아직 읽지 않는 새 묶음이다 | 가능 |
| S2 버티기 판 문 소리(2026-10-11, `s2/audio/`, 6개 합쳐 131KB): 두드림 `door_bang/`, 뚫림 `door_break/`, 방벽 무너짐 `door_wall/`에 둘씩(`_01~02.wav`) | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx)(rubberduck)의 wood_slam_01, wood_slam_03, wood_hit_03, wood_hit_05, wood_hit_08, wood_hit_09, wood_breaking_01~02, wood_falling_01~04, wood_falling_06.ogg, [75 CC0 breaking / falling / hit sfx](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx)(rubberduck)의 bfh1_wood_breaking_01, bfh1_wood_breaking_03, bfh1_wood_falling_02.ogg | 모두 CC0 (2026-10-11 쪽 표기 확인, 청취 안 함) | 진짜 문 녹음이 아니라 나무 소리를 겹쳐 만든 파일이다. 두드림: 나무 쾅에 낮은 나무 치는 소리를 −3dB로 겹치고 450ms에서 자름, 가장 큰 값 −3dB. 뚫림: 나무 부서짐 둘(둘째는 40~60ms 뒤 −3dB)에 떨어지는 조각(200~220ms 뒤 −6dB)을 겹치고 900ms에서 자름, −2dB. 방벽 무너짐: 판자 떨어지는 소리에 나무 치는 소리(100~120ms 뒤 −4dB)와 또 떨어지는 소리(240~260ms 뒤 −5dB)를 겹치고 800ms에서 자름, −3dB. 모노 22050Hz 16비트. 아무도 들어 보지 않았다 | 가능 |
| S1 손끝 소리(2026-10-11 받음, `s1/src/audio/clips/`, 처음 18개 258KB. 2026-10-12에 막힘을 하나로 줄여 16개 221KB): 놋쇠 누름 `enamel_press_1~3.wav`, 놋쇠 확정 `enamel_confirm_1~3.wav`, 레버 걸림 `lever_notch_1.wav` | [Kenney UI Audio](https://kenney.nl/assets/ui-audio)(Kenney Vleugels)의 click4, click5, switch8.ogg(누름), switch21, switch23, switch22.ogg(확정), click3.ogg(걸림) | CC0 (2026-10-11 쪽과 묶음 안 License.txt 확인, 청취 안 함) | 모노 44100Hz 16비트로 바꾸고 가장 큰 값을 누름·걸림 −9dB, 확정 −6dB로 맞춤. 누름 90ms, 확정 400ms, 걸림 70ms에서 자름. 열여덟 개 모두 이름과 잰 값만 보고 골랐고 아무도 들어 보지 않았다 | 가능 |
| 같은 묶음: 레버 걸림 `lever_notch_2~3.wav` | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds)(Kenney)의 click_002, click_003.ogg | CC0 (2026-10-11 확인, 청취 안 함) | 모노 44100Hz 16비트, 가장 큰 값 −9dB. 길이가 0.01초인 아주 짧은 틱이다 | 가능 |
| 같은 묶음: 종이 누름 `paper_press_1~2.wav`, 막힘 `denied_2.wav`(사용자가 듣고 고른 소리다, 결정 160. 같이 넣었던 `denied_1`, `denied_3`은 2026-10-12에 뺐다) | [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)(Kenney Vleugels)의 bookFlip3, bookFlip2.ogg(누름), bookPlace2.ogg(막힘) | CC0 (2026-10-11 확인. 막힘은 사용자가 들음, 종이 누름은 사용자가 듣고 별로라고 해 바꿀 차례다) | 종이 누름은 가장 큰 순간 둘레 90ms만 잘라 −12dB, 막힘은 220ms에서 잘라 −8dB. 모노 44100Hz 16비트 | 가능 |
| 같은 묶음: 종이 누름 `paper_press_3.wav` | [Turned Page(0164)](https://bigsoundbank.com/turned-page-s0164.html)(DavidGreck, BigSoundBank)의 0164.ogg | CC0 (2026-10-11 쪽 표기 「CC0 (public domain)」 확인, 청취 안 함) | 가장 큰 순간 둘레 90ms만 잘라 −12dB. 모노 44100Hz 16비트 | 가능 |
| 같은 묶음: 종이 확정(펜 한 획) `paper_confirm_1~3.wav` | [Pencil, signature #2(3237)](https://bigsoundbank.com/pencil-signature-2-s3237.html), [Pencil #3(3234)](https://bigsoundbank.com/pencil-3-s3234.html)(둘 다 Joseph SARDIN & Axeline T., BigSoundBank)의 3237.ogg, 3234.ogg | CC0 (2026-10-11 쪽 표기 확인, 청취 안 함) | 긴 녹음에서 한 획씩 자름: 3237의 0.20초부터 440ms, 3234의 0.36초부터 335ms와 1.24초부터 325ms. 200Hz 아래를 깎고 −9dB로 맞춤. 모노 44100Hz 16비트 | 가능 |
| S1 멈춘 열차 연출의 달림 `s1/src/audio/stall/run.wav`(2026-10-11, 84KB). 사용자가 듣고 고르기 전의 임시 소리다 | [Steam engine, foley #1(3310)](https://bigsoundbank.com/steam-engine-foley-1-s3310.html)(Joseph SARDIN & Axeline T., BigSoundBank)의 3310.ogg | CC0. 쪽의 글: 「CC0 (public domain): Free and royalty-free」(2026-10-11 확인, 청취 안 함) | 진짜 기관차가 아니라 소리 만드는 사람이 낸 칙칙폭폭이다. 2초 근처에서 네 박(한 박 0.48초)을 이음매 30ms를 겹쳐 되풀이로 자름, 가장 큰 값 −6dB, 모노 22050Hz 16비트. 아무도 들어 보지 않았다 | 가능 |
| 같은 연출의 급제동 `s1/src/audio/stall/brake.wav`(2026-10-12, 47KB). S2 필드의 멈춘 열차가 서는 연출도 같은 파일의 사본을 썼으나, 2026-10-24 사용자가 「어어어엌」 같다고 해 S2 쪽은 직접 만든 소리로 바꿨다(위 S2 정차 소리 줄). S1 파일은 그대로다. 사용자가 고른 소리다(결정 141). 뒤에 바꿔야 하면 이 파일 하나만 바꾸면 된다 | [SSE Library: TRAINS](https://archive.org/details/SSE_Library_TRAINS)(archive.org, 올린 계정 jscott, 모음 「usc-sound-effect-archive」, 2023-05-19 올림)의 `BRAKE/TRNBrake_Train wheels stopping hard; rusty squeaks_CS_USC.wav`(681,310바이트, 4.72초). 쪽 설명: 「Sound effects from the USC Cinema and/or the Sunset Editorial Collection」 | 쪽의 라이선스 표시는 CC0 1.0(`creativecommons.org/publicdomain/zero/1.0/`, 2026-10-12 다시 확인). **원 권리자는 받은 쪽에서 확인되지 않음, 사용자 결정 141.** 옛 영화 효과음 테이프를 대학이 물려받아 올린 것이라 처음 만든 곳이 어디인지, 그곳이 권리를 내려놓았는지는 쪽에 없다 | 3.0초부터 1.1초를 잘라 앞 10ms를 올리고 끝 200ms를 내림, 가장 큰 값 −3dB, 모노 22050Hz 16비트. 작업자는 들어 보지 않았다. 같은 모음의 다른 파일(달림, 김 빠짐 후보)은 이 결정에 들어 있지 않아 쓰지 않는다. 스토어에 내기 전에 이 파일을 다시 본다 | 가능(사용자 결정 141, 출시 전에 다시 봄) |
| 같은 연출의 김 빠짐 `s1/src/audio/stall/steam.wav`(80KB). 사용자가 듣고 좋다고 한 둘 가운데 하나다(결정 160) | [Steam release sounds](https://opengameart.org/content/steam-release-sounds)(bart)의 steam hisses - Marker #3.wav | CC0 (쪽의 License 칸, 2026-10-11 확인, 청취 안 함) | 받은 그대로에 끝 900ms를 내림, 가장 큰 값 −8dB, 모노 22050Hz 16비트. 진짜 열차 소리인지는 받은 곳에 안 적혀 있다 | 가능 |
| S1 멈춘 열차가 서 있는 동안의 바람 `s1/src/audio/stall/wind.wav`(2026-10-11, 172KB). 임시 소리 | [Wind](https://opengameart.org/content/wind)(ignasd)의 wind.ogg. 위 필드 줄의 `wind/wind.ogg`와 같은 재료 | CC0 (2026-10-10 쪽 표기 확인, 청취 안 함) | 2초부터 4초 동안을 잘라 120Hz 아래를 깎고 이음매 400ms를 겹쳐 되풀이로, 가장 큰 값 −9dB, 모노 22050Hz 16비트. 아무도 들어 보지 않았다 | 가능 |
| S1 멈춘 열차가 다시 달릴 때의 기적 `s1/src/audio/stall/whistle.wav`(2026-10-11, 91KB). 임시 소리 | [Steam whistle](https://opengameart.org/content/steam-whistle)(bart)의 steamwhistle_0.wav. 위 필드 줄의 `whistle/whistle.wav`와 같은 파일 | CC0 (2026-10-10 쪽 표기 확인, 청취 안 함) | 필드 파일 그대로(2.1초, 가장 큰 값 −1dB, 모노 22050Hz 16비트). 아무도 들어 보지 않았다 | 가능 |
| 받아 두고 아직 빌드에 안 넣은 소리 원본(2026-10-11 받음, 저장소 밖에 둠). 문 소리, 조짐 묶음, 들이쉼의 재료다 | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx)(rubberduck), [Bird chirping sounds](https://opengameart.org/content/bird-chirping-sounds)(syncopika)의 birdchirping071414.wav, [Crow caw](https://opengameart.org/content/crow-caw)(zeroisnotnull)의 crow_caw.wav, [Dog barking mono](https://opengameart.org/content/dog-barking-mono)(Brandon Morris)의 dog_barking_mono.wav, [Knocking on wood or door.ogg](https://commons.wikimedia.org/wiki/File:Knocking_on_wood_or_door.ogg)(stephan, 위키미디어 공용), BigSoundBank의 [Flight of a Pigeon(0840)](https://bigsoundbank.com/flight-of-a-pigeon-s0840.html), [Crows(0754)](https://bigsoundbank.com/crows-s0754.html), [Drops of water 1(1384)](https://bigsoundbank.com/drops-of-water-1-s1384.html), [Grinding metal gate 1(0303)](https://bigsoundbank.com/grinding-metal-gate-1-s0303.html), [Man breathing(2195)](https://bigsoundbank.com/man-breathing-s2195.html) | CC0. 위키미디어 것은 만든 사람이 공공 영역으로 내놓았다. Dog barking mono는 OGA-BY 3.0과 CC0가 같이 걸려 있어 CC0로 받았다 (2026-10-11 쪽 표기 확인, 청취 안 함. 0754·1384·0303·2195는 찾아 준 워커가 쪽을 읽었다) | 빌드에 넣을 때 쪽을 다시 열어 확인하고, 가공 내역과 함께 줄을 따로 쓴다. 0754·1384·0303·2195는 넣기 전에 이 줄기가 쪽을 직접 읽는다 | 가능 |
| 받아 두고 아직 빌드에 안 넣은 소리 원본 둘째(2026-10-11 받음, 저장소 밖에 둠). 멈춘 열차 연출(달림, 급제동, 선 뒤)의 후보 재료다. 급제동은 정해졌고(결정 141, 위 급제동 줄) 달림과 선 뒤는 사용자가 듣고 고르기 전이다 | BigSoundBank의 [Steam locomotive, between 2 wagons(3020)](https://bigsoundbank.com/steam-locomotive-between-2-wagons-s3020.html), [Steam locomotive #1(3016)](https://bigsoundbank.com/steam-locomotive-1-s3016.html), [Steam Locomotive #2(3018)](https://bigsoundbank.com/steam-locomotive-2-s3018.html), [Steam locomotive, stop(3015)](https://bigsoundbank.com/steam-locomotive-stop-s3015.html), [Steam engine, foley #1(3310)](https://bigsoundbank.com/steam-engine-foley-1-s3310.html), [Steam engine, foley #2(3311)](https://bigsoundbank.com/steam-engine-foley-2-s3311.html), [Metro: Stopping and starting #1(3039)](https://bigsoundbank.com/metro-stopping-and-starting-1-s3039.html), [#2(3041)](https://bigsoundbank.com/metro-stopping-and-starting-2-s3041.html), [Metal grinding #2(0857)](https://bigsoundbank.com/metal-grinding-2-s0857.html), [#3(1043)](https://bigsoundbank.com/metal-grinding-3-s1043.html)(모두 Joseph SARDIN)의 ogg, [Steam release sounds](https://opengameart.org/content/steam-release-sounds)(bart)의 steam_hisses.zip, 그리고 [SSE Library: TRAINS](https://archive.org/details/SSE_Library_TRAINS)(USC Cinema·Sunset Editorial 모음, archive.org에 올린 것)의 wav 다섯 | BigSoundBank와 OpenGameArt는 CC0 (2026-10-11 쪽 표기 「CC0 (public domain)」, 「License(s): CC0」 확인, 청취 안 함). SSE는 쪽에 CC0 1.0 표시가 있으나 옛 영화 효과음 테이프를 대학이 물려받아 올린 것이라 원 권리자가 누구인지 쪽에서 확인되지 않는다 | 가공 전. SSE에서 온 다섯 가운데 급제동 하나만 사용자 결정 141로 넣었다. 나머지 넷은 빌드와 저장소에 넣지 않는다 | 가능(SSE는 급제동 하나만 결정 141로 쓰고 나머지는 쓰지 않음) |
| Mixkit 효과음(군중, 열차) | [Mixkit](https://mixkit.co/free-sound-effects/crowd/), [효과음 약관](https://mixkit.co/license/modal/sfxFree/) | Sound Effects Free License | 상업 게임 가능, 표시 불필요. 원음이나 소재 묶음으로 다시 나눠 주는 것은 금지 | 약관 확인 필요 |
| ZapSplat | [라이선스 안내](https://www.zapsplat.com/license-type/standard-license/) | 무료형은 MP3·출처 표시, 유료형은 WAV·무표기 | 기본 1인 라이선스 | 형에 따라 |
| BBC Sound Effects | [안내](https://blog.prosoundeffects.com/how-to-license-bbc-sound-effects-to-use-in-your-commercial-productions) | 상업 이용은 유료 허가 | 쓰려면 사용자에게 묻는다 | 허가 범위 |
| 유료 열차 라이브러리(BOOM TRAINS 등) | sound_music.md 11장 | 상품마다 다름, 사용 인원별 | 쓰려면 사용자에게 묻는다(5단계) | 상품마다 |

### 음악

| 자산 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|
| 옛 노래의 곡(Es klappert die Mühle 등, sound_music.md 9.3) | 각 곡 출처 링크 | 공공 영역(사이트 표기, 원곡 판본을 다시 확인) | 곡만 쓴다. 편곡과 녹음은 우리가 새로 만들고 따로 줄을 만든다 | 가능 |
| 비발디 '겨울' 곡 | [IMSLP](https://imslp.org/wiki/Winter_(Vivaldi,_Antonio)) | 공공 영역 | 기존 연주 녹음과 현대 판본 악보는 쓰지 않는다 | 가능 |
| Suno Pro 또는 Premier 생성곡 | [suno.com/terms](https://suno.com/terms) | 2026-08-10 개정·09-03 시행 약관(2026-10-09 소넷 워커가 읽음): 유료 요금제에서 그달 다운로드 몫(Pro 20곡, Premier 60곡)으로 받은 곡만 상업 이용, 받은 곡의 상업권은 해지 뒤에도 유지. 무료는 다운로드 불가 | 다운로드하지 않은 곡과 리믹스는 상업 이용 불가. 곡마다 만든 날, 요금제, 모델, 받은 날을 적는다. 소유권 표현('양도'인지 '상업권'인지)은 원문으로 다시 확인 | 약관 확인 필요 |
| AI 음성 생성 외침(의회 군중·'정숙!', 후보 ElevenLabs 유료 요금제) | elevenlabs.io | 유료 구독 중 만든 음성은 해지 뒤에도 상업 이용 가능(2026-10-08 도움말 확인, 10-09 다시 확인). 무료 요금제 생성물은 상업 이용 불가이고 공개할 때 elevenlabs.io 표시가 필요하다(10-09). 군중 소리 재료로만 쓴다(주인공·주요 인물 대사 아님, 사용자 10-09). 다른 후보: Gemini TTS(무료 몫 생성물의 상업 조항 불분명, 남길 것은 유료로), 열린 가중치 MOSS-TTS v1.5(Apache-2.0) | 목소리는 Voice Design(글로 만든 합성 목소리)이나 라이브러리 목소리만 쓰고 실제 사람 목소리 복제는 하지 않는다. 대사마다 만든 날, 요금제, 모델, 목소리 이름을 적는다. 영수증은 PC에만 | 결제 전(sound_ai_voice.md 카드) |
| Stable Audio 생성곡(웹 서비스) | [상업·사용권 안내](https://kb.stability.ai/knowledge-base/stable-audio-commerical-and-usage-licensing), [약관](https://stability.ai/terms-of-service) | 무료 요금제 생성물도 모바일 앱·게임 배경음에 넣을 수 있다고 도움말이 명시(10-09 Codex luna 확인, 약관 시행 2026-09-30) | 쓸 때 약관을 다시 연다 | 약관 확인 필요 |
| Stable Audio 3 Small·Medium 생성곡(열린 가중치) | [Hugging Face](https://huggingface.co/stabilityai/stable-audio-3-medium), [stability.ai/license](https://stability.ai/license) | Stability AI Community License: 연 매출 $1M 미만 무료, 넘으면 기업 라이선스. 생성물은 사용자 소유. 텍스트 인코더에 Gemma 약관이 같이 걸린다(10-09 소넷 워커, 원문 다시 확인) | 매출 기준을 넘으면 라이선스를 사야 한다. 보컬 없음 | 조건부 |
| ACE-Step 1.5 생성곡(열린 가중치) | [GitHub](https://github.com/ace-step/ACE-Step-1.5) | 코드·가중치 MIT, 모델 카드가 생성물 상업 이용을 명시(10-09 소넷 워커, 원문 다시 확인) | 학습 자료 세부는 공개 안 됨. 노래 시안 후보 | 가능(확인 뒤) |
| AIVA Pro 생성곡 | [aiva.ai/pricing](https://aiva.ai/pricing) | Pro는 저작권을 넘겨받음(10-09 다시 확인, 연 결제 월 €33, 월 300곡 다운로드) | 무료·Standard 요금제는 조건이 다르다. 해지 뒤 조건 미확인 | 가능(Pro) |
| ElevenLabs Music 생성곡 | [Music 약관](https://elevenlabs.io/music-terms) | 2026-10-09 약관이 바뀌었다: 돈 버는 게임은 'Studio Game', 그중 누적 매출 $50만 미만이고 회사 게임 매출 $100만 미만이면 'Indie Game'으로 따로 둔다. 요금제별 권리표(Exhibit A)는 확인 못 함(10-09 Codex luna) | 인디 게임으로 셀프 구독에서 쓸 수 있는지는 권리표를 읽어야 안다. 그 전엔 쓰지 않는다 | 미정 |
| 쓰지 않음: Udio(다운로드 막힘), MusicGen(가중치 비상업), XTTS-v2·F5-TTS·Fish Speech·Higgs v3(비상업) | 각 약관 | 10-09 확인 | | 안 됨 |

AI로 만든 음악과 그림은 줄마다 'AI 생성'을 적는다. 사람이 손본 내역(편곡, 녹음, 믹스)도 같이 적는다. AI 생성물은 저작권 보호가 약해서 사람이 고친 부분이 권리의 근거가 되고, Steam은 출시 때 AI 사용을 밝히라고 한다.

## 3. 빌드와 맞춰 보기

플레이 빌드를 낼 때마다 한다.
1. 빌드에 실제로 든 글꼴, 소리, 음악, 그림, 3D 파일 목록을 뽑는다.
2. 목록의 파일마다 1장에 줄이 있는지 본다. 없는 파일은 빌드에서 빼거나 줄을 만든다.
3. 1장에서 '조건'에 표시 문구가 있는 줄이 크레딧과 고지에 모두 들어갔는지 본다.
4. 빌드에서 빠진 파일의 줄은 2장으로 내린다.

지금은 빌드에 남의 소리·글꼴·그림 파일이 없어서 1장의 Godot 고지만 남는다. 파일이 들어오기 시작하면 이 맞춰 보기를 스크립트로 만든다.

## 4. 그림·3D

화면 스레드와 3D 스레드가 위와 같은 칸으로 채운다. 렌더 시안은 바탕화면\좀비\에만 두고 빌드에 넣지 않으므로 지금은 1장 줄이 없다.

### 후보: 화면(UI 재질, 조짐 흔적, 성에) (2026-10-07 화면 스레드, Pro 수집 r5)

| 자산 | 종류 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|---|
| Paper 001 | 그림(종이 재질) | [ambientCG](https://ambientcg.com/view?id=Paper001) | CC0 (r5 30, 표기만 확인) | 표시 의무 없음. 크레딧에는 넣는다. 법안·카드 종이 바탕(presentation_motion.md 3절) | 가능 |
| Snow-Covered Surface 셰이더 | 코드 | [godotshaders.com](https://godotshaders.com/shader/snow-covered-surface/) | 코드만 CC0 (r5 22) | 시연 그림·영상·에셋은 포함 안 됨. 3D 스레드와 같이 씀 | 가능 |
| 눈·모래 위 바퀴 자국 셰이더 | 코드 | [godotshaders.com](https://godotshaders.com/shader/car-tracks-on-snow-or-sand-using-viewport-textures-and-particles/) | 코드만 MIT (r5 37) | MIT 고지를 넣는다. 지금 방향은 이 방식 대신 찍는 조각(8b절)이라 쓸지 미정 | 가능 |
| Bloody Pool 셰이더 | 코드 | [godotshaders.com](https://godotshaders.com/shader/bloody-pool-smooth-blood-trail/) | 코드만 MIT (r5 39) | MIT 고지. 폰 비용 확인 전엔 쓰지 않는다 | 가능 |

### 후보: 3D(열차·사람·재질·조명) (2026-10-07 3D 스레드)

라이선스는 조사 문서의 표기를 옮긴 것이고 3D 스레드가 원문을 다시 열어 보진 않았다. 파일을 받을 때 원문을 열고 확인한 날을 고쳐 적는다. 회색 상자용 묶음은 출시판에서 직접 만든 모델로 바뀔 수 있다.

| 자산 | 종류 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|---|
| Snow 015 | 그림(눈 재질) | [ambientCG](https://ambientcg.com/view?id=Snow015) | CC0 (r5 24, 표기만 확인) | 표시 의무 없음. 크레딧에는 넣는다. 폰용으로 해상도·맵을 줄여 쓴다. 역사 주변 지저분한 눈, 칸 지붕 눈 층 | 가능 |
| Passendorf Snow HDRI | 3D(조명 환경) | [Poly Haven](https://polyhaven.com/a/passendorf_snow) | CC0 (r5 25, 표기만 확인) | 맑은 날 자료라 흐린 날·폭설 기준으로 쓰지 않는다. 재질 조명 시험용, 빌드에 넣을지는 미정 | 가능 |
| Improved frosted glass 셰이더 | 코드 | [godotshaders.com](https://godotshaders.com/shader/improved-frosted-glass/) | 코드만 CC0 (r5 23) | 시연 그림·영상은 포함 안 됨. 객차 창 성에 시험. 폰 비용 확인 전 | 가능 |
| Snow-Covered Surface 셰이더 | 코드 | 위 화면 줄과 같음 | 코드만 CC0 (r5 22) | 화면과 같이 씀. 칸 지붕·난간·화물 위 눈 | 가능 |
| Quaternius Universal Base Characters | 3D(사람 기본 몸) | [quaternius.com](https://quaternius.com/packs/universalbasecharacters.html) | CC0 (art_reference_scan_20261007.md 68줄, 팩 페이지 표기) | 미리보기 그림의 권리는 따로 확인 못 함. 사람 기본 몸 후보 | 미정 |
| Quaternius Universal Animation Library | 3D(동작) | [quaternius.com](https://quaternius.com/packs/universalanimationlibrary.html) | CC0 (같은 문서 69줄) | 사람 동작 후보. 1·2의 동작 여섯은 2026-10-18 빌드에 넣어 1장에 적음 | 미정 |
| MPFB 플러그인(Blender) | 도구 | MakeHuman 커뮤니티 | GPL로 알려짐(미확인, 받을 때 원문 확인) | 만드는 도구로만 쓰고 게임에 넣지 않는다. 'GPL은 참고만' 규칙은 게임에 들어가는 코드 얘기라 도구 사용은 걸리지 않는다 | 해당 없음 |
| MPFB로 만든 몸과 MakeHuman 에셋 | 3D(사람 몸) | MakeHuman 커뮤니티 | CC0로 알려짐(미확인, 받을 때 원문 확인) | 쓰는 에셋 묶음마다 라이선스를 따로 연다 | 미정 |
| Kenney Train Kit | 3D(열차 회색 상자) | [kenney.nl](https://kenney.nl/assets/train-kit) | CC0 (같은 문서 70줄) | S2 회색 상자용. 출시판 열차는 T1 부품 키트로 직접 만든다 | 미정 |
| Kenney Modular Buildings | 3D(건물 회색 상자) | [kenney.nl](https://kenney.nl/assets/modular-buildings) | CC0 (같은 문서 71줄) | 회색 상자용 | 미정 |
| Kenney Furniture Kit | 3D(가구 회색 상자) | [kenney.nl](https://kenney.nl/assets/furniture-kit) | CC0 (같은 문서 72줄) | 회색 상자용 | 미정 |

'홍보'가 미정인 줄은 회색 상자용이라 실제 게임 화면에 남을지가 정해지지 않았다는 뜻이다. 남으면 그때 '가능'으로 고친다(CC0라 막히는 건 없다).

| GUGiK 건물 모델 LoD1·LoD2, 수치지형 NMT, 정사영상 ORTO, 레이저 점군 | 3D·지형 원자료 | [geoportal.gov.pl](https://www.geoportal.gov.pl/pl/dane/inne-dane/modele-3d-budynkow/) | 무료·자유 이용 안내와 재사용 지침은 있음. **상업 게임 사용은 미확인**(2026-10-07 조사 21) | 확인 전에는 모델·지형을 불러오지 않고 눈으로 보는 참고로만 쓴다. 쓰게 되면 출처 문구(기관명, 자료명·버전, 취득일, 가공 내용)를 넣는다 | 미확인 |

### 레퍼런스로만 보는 것 (빌드·홍보에 넣지 않음)

줄을 만들지 않고 규칙만 적는다. 아래는 보고 형태만 따는 자료라 파일을 빌드나 스토어 페이지에 넣지 않는다.
- 박물관 사진 중 CC BY-NC-SA(r5 10~12 드레스덴 교통박물관, 31·32 Science Museum Group 압력계): 비상업 조건이라 상업 게임에 못 넣는다.
- 구간 배경 사진(segment_backdrops_20261007.md 표, Commons CC BY·BY-SA 등): 바탕화면 `좀비\구간배경_20261007\ref\`에서 사람이 비교만 한다. 이미지 모델에 첨부하지 않는다.
- 다른 게임의 화면·아트북·제작기(프로스트펑크 2 등): 구성 원리만 본다.
- 프로스트펑크 1 설치본을 행동 구조 참고로만 분석, 에셋·코드 미반입.

### 후보: 트리포 생성 소품 (2026-10-09 트리포 스레드)

| 자산 | 종류 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|---|
| 트리포 맥스 요금제로 만든 소품·건물 조각 | AI 생성(3D) | [tripo3d.ai](https://www.tripo3d.ai/terms) | 약관 2025-07-11 개정판: 유료 회원은 입력·출력 권리를 대체로 가짐, 무료 회원 생성물은 트리포가 권리를 가짐(2026-10-09 요약 도구로 읽음, 원문 다시 열 것) | 유료 기간에만 만든다. 해지 뒤 권리 유지와 공개 저장소 보관은 약관에 문장이 없어 트리포에 글로 묻는다. 원본은 PC에만, 가공한 모델만 빌드에. 모델마다 만든 날, 트리포 모델 버전, 입력 그림 출처, 손본 내역을 적는다. 영수증은 PC에만. 세부: [../art/tripo_pipeline.md](../art/tripo_pipeline.md) 5장 | 미정(Steam AI 공개 필요) |

### AI 생성 렌더 시안

C·B·M 렌더 시안(concept_renders, segment_backdrops, 바깥 눈 점검 주문)과 3D 스레드의 M·T·F 시안(model_renders_20261007.md, train_cars_20261007.md)은 아스트라 울트라 등으로 만든 AI 생성물이고 바탕화면\좀비\에만 있다. 스토어 페이지, 트레일러, 홍보 스크린샷에 시안을 쓰려면 그 전에 이 장에 줄을 만들고 만든 도구, 요금제, 만든 날, 사람이 손본 내역을 적는다. 기본값은 홍보에 시안을 쓰지 않고 실제 게임 화면을 쓰는 것이다.
