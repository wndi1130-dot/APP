# models/people — 구운 사람·망자 몸

몸 한 벌은 폴더 하나다(`mesh.res`, `clips.json`, `vat.bin`, 있으면 `albedo.png`). 망자 동작(15클립 또는 30클립)을 구운 폴더는 몸 이름 그대로(`n5-crew_driver/`), 산 사람 동작판(60클립, `bake_body_cli.gd --set=person`)은 끝에 `_p`(`n5-crew_driver_p/`), 열차 칸 동작판은 `_t`다.

## 산 사람이 입는 몸

필드의 산 사람은 사람마다 다른 몸을 입는다. 누가 어떤 몸인지는 `game/actors/body_cast.gd`, 그리기는 `game/actors/person_visual.gd`(몸마다 multimesh 둘, 처음 입는 사람이 나올 때 한 프레임에 한 벌씩 읽음). 망자가 입는 몸(`dead_body.gd` BUILT_IN, 운동복)은 산 사람 목록에 넣지 않는다.

| 누구 | 몸 |
|---|---|
| 열차장 | n5-crew_railman-old |
| 경비칸 동료 | n5-crew_guard (평상 외투, 제복·휘장 없음) |
| 의무칸 동료 | n5-crew_medic |
| 꼬리칸 동료 | n3-body_sheepskin |
| 약탈자 셋 | n3-body_lumberjack, n10-body_woodsman-m, n10-body_duffel-m |
| 작업조 넷 | n5-crew_stoker, n5-crew_fitter, n10-body_overalls-m, n5-crew_driver |
| 호위조 둘 | n5-crew_guard-f, n5-crew_hunter-f |

필드에 한꺼번에 나오는 사람은 많아야 열셋이라 모두 다른 몸이다. 열네 번째부터는 가장 적게 입은 몸을 같이 입는다. `n5-crew_seamstress_p`는 기준 몸으로 남겨 두고, 자기 몸 폴더가 빌드에 없는 사람이 입는다.

## 굽는 법

리깅된 몸 glb(저장소 밖)마다:

```
godot --headless --path s2 --script tools/bake_body_cli.gd -- <몸.glb> <UAL1_Standard.glb>,<UAL2_Standard.glb> models/people/<몸>_p --check --small --set=person --keep=<BodyBake.PERSON_KEEP를 쉼표로>
```

색 그림은 같은 glb 안에 든 512 한 장을 `albedo.png`로 꺼내 둔다(망자 폴더에는 없고, 그리기는 `_p`의 것을 쓴다). 면이 성긴 몸은 팔꿈치 5cm 안에 꼭짓점이 없을 수 있어 `person_visual.gd hand_of`가 가장 가까운 꼭짓점 둘레로 넓혀 찾는다.

쓰지 않는 몸: `n10-body_oilskin-m`, `n10-body_coalworker-m`은 리깅이 비틀려 팔이 옆으로 뻗는다.

## 폰 예산(PC에서 잼, 폰은 아직 안 잼)

| | 한 벌 | 필드 보통(우리 넷 + 약탈자 셋 = 7벌) | 필드 가장 많을 때(13벌) |
|---|---|---|---|
| 파일(`_p` 폴더) | 3.6~4.4 MB | — | 13벌 합 51 MB |
| GPU(사람 동작 그림 RGBA8 + 망자 동작 그림 + 색 512) | 6.4~7.5 MB | 약 48 MB | 89 MB |
| 읽기 | 60~90 ms | — | — |

낮은 폰에서 줄이는 자리: 프로젝트 설정 `visuals/people_bodies_max`(0이면 상한 없음). 예를 들어 8이면 한 장면에서 몸은 8벌까지만 읽고, 아홉째 사람부터는 이미 입은 몸 가운데 가장 적게 입은 몸을 같이 입는다(이름 있는 넷은 먼저 자기 몸). 8벌이면 GPU 약 55 MB다. 폰 측정은 시험 단계에서 한다.

전에는 모두 재봉 몸 한 벌(GPU 17 MB, 손 자리 표 만들기 때문에 읽기 1.5초)이었다. 다음에 줄일 길: 동작 그림의 열은 꼭짓점마다인데 색 그림 이음매로 갈라진 꼭짓점이 많아, 실제 자리는 몸마다 730~780개뿐이다(꼭짓점 1,200~2,700). 같은 자리 꼭짓점이 한 열을 같이 쓰게 구우면 동작 그림이 40~70% 준다.
