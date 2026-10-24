# n5-crew_seamstress_t — 열차 사람 동작

재봉 몸(`../n5-crew_seamstress/`와 같은 메시·색 그림)에 열차 칸 사람 동작만 구운 폴더(결정 421-4). 필드 폴더(`_p`)의 번호는 건드리지 않는다. 동작 목록과 손으로 쓴 층은 `game/train/train_clips.gd`, 굽는 도구는 `tools/bake_train_cli.gd`(body_bake.gd는 읽기만 한다). 그리는 쪽은 `game/train/train_people_view.gd`로, 게임은 번호가 아니라 이름(`clips.json`)으로 찾는다.

굽는 법(원본 glb는 저장소 밖):
`godot --headless --path s2 --script tools/bake_train_cli.gd -- <seamstress.glb> <UAL1_Standard.glb>,<UAL2_Standard.glb> res://models/people/n5-crew_seamstress_t --check --small`

`--small`은 8비트 압축판이다. `t_shiver`·`t_cough`는 떨림·기침 박자가 빨라 모든 틀을 남긴다(`TrainClips.KEEP`).

| 동작 | 원본(UAL) | 쓰는 때 |
|---|---|---|
| t_sit, t_sit_talk | Sitting_Idle_Loop, Sitting_Talking_Loop | 긴 의자에 앉음, 옆과 이야기 |
| t_sit_huddle, t_sit_doze | Sitting_Idle_Loop + 층 | 추위·두려움에 웅크림, 밤에 앉아 졺 |
| t_stand, t_walk, t_carry | Idle_Loop, Walk_Loop, Walk_Carry_Loop | 서 있기, 통로 걷기, 짐 나르기 |
| t_fold, t_talk, t_no | Idle_FoldArms_Loop, Idle_Talking_Loop, Idle_No_Loop | 팔짱(원망·경비), 말다툼 |
| t_lantern | Idle_Lantern_Loop | 경비칸 밤 지키기 |
| t_crouch, t_warm_hands | Crouch_Idle_Loop (+ 층) | 바닥 웅크림, 난로에 손 쬐기 |
| t_kneel_work | Fixing_Kneeling 0.2~0.8 | 수리·치료 |
| t_eat | Consume | 배급 그릇 |
| t_shovel, t_stir | Farm_Harvest, Farm_Watering | 석탄 삽질, 솥 젓기 |
| t_lie, t_floor_sit | LayToIdle 처음·0.3 지점 고정 | 침상·바닥에 눕기, 바닥에 앉기 |
| t_shiver, t_cough | Idle_FoldArms_Loop·Idle_Loop + 층 | 떨기, 기침 |
