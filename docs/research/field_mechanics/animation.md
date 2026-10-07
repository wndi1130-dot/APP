# 애니메이션과 3D 캐릭터: 어떻게 작동하나

작성: 2026-10-07 · 조사: 웹 GPT 워커(사용자 요청) · 정리: 조사 스레드

좀보이드 캐릭터 애니메이션의 구조, 한 골격으로 여러 상태를 내는 법, 폰에서 좀비 수십~수백 마리를 움직이는 법을 정리했다. 열차·사람 동작 참고는 [ref/animation_references.md](../../../ref/animation_references.md), 모션 팩과 도구는 [사용자 조사 브랜치의 animation_resources_v6.md](https://github.com/wndi1130-dot/APP/blob/research/3d-resources-and-art-direction-20261007/ref/art/animation_resources_v6.md)에 있다. 여기서 겹치는 링크는 없다. 표시는 [README](README.md)를 따른다.

## 한눈에

- 좀보이드 B41 애니메이션은 **상태(AnimState) → 변형(AnimNode) → 트랙(AnimTrack)** 3단이다. 큰 행동 상태는 하나만 켜고, 그 안에서 무기·방향·자세에 맞는 변형을 가중치로 섞고, 실제 뼈에는 여러 트랙을 섞는다. [1차]
- 걷기+조준+재장전 조합을 다 따로 만들지 않는다. **조건으로 고르는 변형 + 상체 뼈 마스크 + 전환 동작**으로 조립한다. [1차]
- 옷은 같은 골격에 실제 옷 메시를 입히고, **바깥옷에 가려진 안쪽 옷 부분을 마스크로 꺼서** 뚫고 나옴을 막는다. [1차]
- 폰 군중은 한 가지 기술로 안 된다. 워커의 결론은 **가까이는 완전 골격, 중간은 GPU 애니메이션, 멀리는 정점 애니메이션 텍스처(VAT), 화면 밖은 논리 상태만**이다. [제안]

## 1. 좀보이드 B41 이후 애니메이션 구조

- 상태는 걷기·서기·은신처럼 큰 행동이고 한 번에 하나다. 변형은 '쇠지렛대 들고 걷기' 같은 것을 고르고 여러 변형을 페이드로 섞는다. 트랙은 실제 뼈에 클립을 섞는다. [1차] [Advanced Zedonometry](https://projectzomboid.com/blog/news/2019/05/advanced-zedonometry/)
- 서기→달리기를 단순 크로스페이드로 잇자 무게중심이 어색해서 `StandingToRunning` 같은 **전환 전용 동작**을 넣었다. 조준할 때 총이 손 사이에 뜨는 문제도 전환 동작으로 메웠다. [1차] [Anim-Transition Blog](https://projectzomboid.com/blog/news/2019/06/anim-transition-blog/)
- 커뮤니티가 게임 데이터에서 뽑은 AnimSets 스키마에는 조건, 이벤트, 전환, 뼈 가중치, 2D 블렌드, 블렌드 시간 항목이 있다. 비공식 자료라 항목이 있다는 것만 믿는다. [2차] [pz-xml-data](https://github.com/PZ-Wiki-Modding/pz-xml-data/blob/main/out/data.json)
- B42는 이 망이 복잡해져 XML 직접 편집 대신 `AnimGraphZeditor`라는 그래프 도구를 만들었다. 두 캐릭터를 묶는 GrappleTech(시체 들기·끌기)도 B42에서 나왔다. [1차] [Tidy Up Time](https://projectzomboid.com/blog/news/2024/08/tidy-up-time/), [D'ya Like Them GrappleZ](https://projectzomboid.com/blog/news/2024/04/dya-like-them-grapplez/)
- 지금 Stable은 42.21(2026-09-28)이다. [1차] [42.21 Stable Released](https://projectzomboid.com/blog/news/2026/09/42-21-stable-released/)

**우리에게**: 층을 이렇게 나누자는 제안이다. [제안]

| 층 | 맡는 것 | 예 |
|---|---|---|
| 상태 | 몸 전체의 큰 행동 | 서기, 이동, 달리기, 쓰러짐, 일어남, 넘기, 죽음 |
| 변형 조건 | 장비·부상·자세 | 소총, 권총, 근접, 다리 부상, 얼어붙음, 조준 |
| 하체 트랙 | 이동 | 걷기, 뛰기, 기기 |
| 상체 트랙 | 무기·도구 | 조준, 발사, 재장전, 휘두르기 |
| 덧셈 트랙 | 상태 이상 | 피격 움찔, 추위 떨림, 숨 |
| 절차 보정 | 마지막 손질 | 총구 방향, 손 위치, 시선 |

무기 원형 15개마다 걷기×달리기×부상×동결×조준을 다 만들지 않는다. 손 위치와 실루엣이 실제로 다른 **자세군**(권총, 장총, 양손 근접, 한손 근접, 맨손)만 따로 두고, 같은 군 안의 차이는 손 IK와 무기 소켓으로 흡수한다. 발사 순간·타격 순간·탄창 삽입·발소리는 애니메이션 이벤트로 게임 규칙에 넘긴다. [제안]

## 2. 한 몸으로 걷기·조준·재장전·휘두르기

- 좀보이드 마스킹은 지정한 뼈에만 애니메이션을 건다. 대표 용도가 '상체만'이다. 그래서 하체로 걸으면서 상체로 재장전한다. [1차] [Mannequin vs. Zed](https://projectzomboid.com/blog/news/2019/06/mannequin-vs-zed/)
- Unity Animation Layers도 하체·상체 상태 머신을 따로 두고 레이어마다 마스크와 덮어쓰기/덧셈을 정한다. 문서 예시에 같은 상태 머신을 두고 클립만 '부상' 판으로 바꾸는 **동기화 레이어**가 있다. [1차] [Animation Layers](https://docs.unity3d.com/kr/current/Manual/AnimationLayers.html)
- Animation Rigging은 Two Bone IK, Multi-Aim, Override Transform 등을 준다. [1차] [Animation Rigging](https://docs.unity3d.com/kr/current/Manual/com.unity.animation.rigging.html), [제약 컴포넌트](https://docs.unity3d.com/ja/Packages/com.unity.animation.rigging%401.2/manual/ConstraintComponents.html)

**모바일에서**: 절차 보정(IK)은 플레이어·동료·화면 가운데 적에게만 켜고, 나머지 좀비는 미리 맞춘 일반 클립을 쓴다. [제안]

## 3. 다리 부상·절단·얼어붙은 자·껴입은 자를 한 골격으로

- **다리 부상**: 2019년 B41 개발판은 상처에 따라 가벼운/심한 절뚝임을 나누고 골절에서 달리기를 막는 것을 시험했다. 당시 작업 중이었으니 지금 규칙으로 읽으면 안 된다. [1차] [Advanced Zedonometry](https://projectzomboid.com/blog/news/2019/05/advanced-zedonometry/) 우리는 걷기 상태를 그대로 두고 부상 값이 정상·경미·중증 걷기 클립을 고르게 한다(Unity 동기화 레이어 방식). [제안]
- **얼어붙은 자**: 골격을 따로 만들 필요가 없다. 팔 흔들림과 척추 회전을 누른 동결 클립을 얹고, 가까운 개체만 관절 회전을 더 제한한다. 중·원거리는 결과를 구운 `얼어붙은 걷기` 클립으로 바꾼다. [제안]
- **절단**: 런타임에 뼈를 없애지 않는다. 골격은 공통으로 두고 잘린 부위의 메시·소켓·피격 판정만 끄거나 절단 전용 메시로 바꾼 뒤, 그 팔을 쓰는 동작을 막는다. 사선 시점에서는 텍스처보다 실루엣이 먼저 읽히므로 소매 끝은 메시로 바꾼다. [제안]
- **껴입은 자**: 좀보이드는 안쪽·바깥 옷을 모두 3D로 만들자 움직일 때 서로 뚫고 나와서, 가려진 안쪽 옷 부분을 마스크로 끈다. [1차] [Red Hand Gang](https://projectzomboid.com/blog/news/2019/03/red-hand-gang/) 그래서 골격을 키우지 말고 외투·목도리·가방 같은 바깥 실루엣을 메시로 더하고 안쪽을 지운다. 군중용은 옷을 겹겹이 따로 두지 말고 한 메시·적은 머티리얼로 굽는다. [제안] [Unity 캐릭터 최적화](https://docs.unity3d.com/kr/current/Manual/ModelingOptimizedCharacters.html)

## 4. 사선 시점에서 캐릭터가 읽히게

- 라이엇은 캐릭터 구별에서 실루엣을 핵심으로 다룬다. Aphelios 개발진은 위에서 보는 카메라 탓에 총 모양이 잘 안 보여 **무기별 자세와 움직임**이 그 일을 대신했다고 말한다. [1차] [Clarity in League](https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/), [Aphelios](https://www.leagueoflegends.com/en-gb/news/dev/champion-insights-aphelios/)
- Darksiders Genesis 개발진도 먼 고정 등각 카메라에서는 머리·상체에 디테일을 모으고 큰 실루엣을 쓴다고 했다. [1차][미확인] [Unreal 인터뷰](https://www.unrealengine.com/developer-interviews/how-darksiders-genesis-successfully-reinvented-itself-as-a-co-op-isometric-action-game)
- Unity 6 리그 가져오기 기본값은 정점당 뼈 4개이고 성능상 권장된다. [1차] [Rig 가져오기](https://docs.unity3d.com/kr/current/Manual/FBXImporter-Rig.html) 옛 2018.4 문서의 '모바일 캐릭터 300~1,500 폴리곤, 뼈 30개 이하'는 레거시이고 현행 문서에서 빠졌다. 목표치로 쓰지 말고 실제 기기에서 잰다. [1차·레거시] [2018.4 문서](https://docs.unity3d.com/kr/2018.4/Manual/ModelingOptimizedCharacters.html)

**우리에게**: 좀비 상태를 색만으로 가르지 않는다. 워커가 낸 실루엣 안이다. [제안]

| 상태 | 멀리서 먼저 보이는 차이 |
|---|---|
| 망자 | 기본 굽은 자세 |
| 갓 일어난 자 | 앞으로 쏠린 상체, 큰 보폭, 빠른 팔 |
| 얼어붙은 자 | 팔꿈치·어깨가 굳은 실루엣, 작은 보폭 |
| 껴입은 자 | 넓은 어깨·몸통, 외투 아랫단 부피 |
| 열 쫓는 자 | 머리·가슴이 목표 쪽으로 끌림 |
| 부르는 자 | 목·가슴을 크게 젖히는 자세 |

무기도 제품보다 **한손/양손, 총열 방향, 팔꿈치 위치, 길이**가 먼저 읽혀야 한다.

## 5. 폰에서 좀비 수십~수백 마리

좀비 한 마리의 비용은 하나가 아니다. 상태 계산, 뼈 자세, 정점 스키닝, 드로우콜, AI·길찾기, 충돌이 따로 병목이라 따로 줄인다. [제안]

- **GPU 스키닝**: 안드로이드 설정의 GPU Skinning은 스키닝과 블렌드 셰이프만 GPU로 옮긴다. Animator 상태 계산이나 AI는 그대로다. [1차] [Android Player 설정](https://docs.unity3d.com/kr/current/Manual/class-PlayerSettingsAndroid.html)
- **인스턴싱**: 일반 GPU 인스턴싱은 `SkinnedMeshRenderer`를 직접 묶지 못한다. [1차] [GPU Instancing](https://docs.unity3d.com/kr/6000.0/Manual/gpu-instancing-enable.html) Unity의 공개 [Animation-Instancing](https://github.com/Unity-Technologies/Animation-Instancing) 예제는 Animator를 끄고 클립·프레임·크로스페이드·LOD를 직접 관리한다. Unity 5.4 시절 것이라 구조만 참고한다. [1차]
- **VAT**: 정점 위치를 텍스처에 구워 셰이더가 읽는다. 한 줄이 한 프레임이다. 골격 계산이 없어 싸지만 절단·손 IK·래그돌과 맞지 않는다. 화면 가장자리에서 걷는 무리에 맞다. [1차] [VFXToolbox VAT](https://github.com/Unity-Technologies/VFXToolbox/blob/master/Documentation~/DCCTools.md)
- **보이는 것만 계산**: `CullingGroup` 문서가 바로 '보이는 캐릭터만 온전한 애니메이션·AI, 멀면 싼 행동'인 군중을 예로 든다. `AnimatorCullingMode.CullCompletely`는 안 보일 때 애니메이션을 멈추고, `Update When Offscreen`을 끄면 화면 밖 스키닝이 멈춘다(기본값 꺼짐). [1차] [CullingGroup](https://docs.unity3d.com/kr/6000.0/Manual/CullingGroupAPI.html), [AnimatorCullingMode](https://docs.unity3d.com/ja/6000.0/ScriptReference/AnimatorCullingMode.html), [Skinned Mesh Renderer](https://docs.unity3d.com/kr/current/Manual/class-SkinnedMeshRenderer.html)
- 좀보이드 개발진도 B41 때 같은 상태의 좀비끼리 적은 골격을 나눠 쓰는 최적화를 예고했다. 실제로 그렇게 구현됐는지는 확인하지 못했다. [1차] [Anim-Transition Blog](https://projectzomboid.com/blog/news/2019/06/anim-transition-blog/)

**우리에게**: 네 단계 표현을 제안한다. [제안]

| 단계 | 누구 | 무엇을 켜나 |
|---|---|---|
| A 전투권 | 플레이어, 동료, 가까운 좀비 | 온전한 Animator, 상·하체 마스크, IK, 피격, 필요하면 래그돌 |
| B 화면 안 군중 | 보이는 좀비 | 구운 골격 애니메이션, 단순 상태, IK 없음 |
| C 먼 화면 | 큰 무리 | VAT, 방향·클립을 드물게 갱신 |
| D 화면 밖 | 다가오는 무리 | 렌더·애니메이션 없음, 어디로 가는지만 |

정차가 길수록 무리가 커지는 규칙과 맞는다. 무리를 다 비싼 개체로 만들 필요 없이 전투권에 들어온 개체만 A로 올린다.

## 6. 피격·넘어짐·래그돌

- 작은 피격은 상체 덧셈 클립(앞·뒤·좌·우)으로 처리한다. `맞음 → 비틀 → 넘어짐`까지는 만든 애니메이션으로, 차·폭발·큰 넉백·죽음처럼 결과를 미리 알기 어려운 때만 래그돌을 켠다. [제안]
- 좀보이드 B42.20은 좀비가 차·총·폭발에 맞으면 래그돌한다. [1차] [Build 42.20 기능](https://projectzomboid.com/blog/features-overview-build-42-20/)
- Unity 래그돌은 뼈마다 강체·콜라이더·조인트다. 솔버 반복을 올릴수록, 연속 충돌 검사일수록 비싸고, 잠든 강체는 계산에서 빠진다. [1차] [Ragdoll Wizard](https://docs.unity3d.com/kr/current/Manual/wizard-RagdollWizard.html), [솔버 반복](https://docs.unity3d.com/jp/current/Manual/physics-optimization-cpu-rigidbody-solver.html), [충돌 모드](https://docs.unity3d.com/ja/current/Manual/physics-optimization-cpu-rigidbody-collision-modes.html), [잠들기](https://docs.unity3d.com/jp/current/Manual/physics-optimization-cpu-rigidbody-sleeping.html)

**우리에게**: 가까이에서만 래그돌을 만들고, 시체가 멈추면 재우고, 멀어지면 단순 시체 메시로 바꾼다. 잘린 팔다리도 잠깐만 물리 개체로 두고 정적 소품으로 넘긴다. [제안]

## 설계에 닿는 점 (결정 아님)

- [zombies.md](../../design/briefs/zombies.md)의 상태 넷·진화 둘은 위 실루엣 표처럼 **자세로 구별**해야 폰에서 읽힌다. 색·텍스처 차이는 보조다.
- [field_unified.md](../../design/briefs/field_unified.md) 9장의 '화면 위 아군 최대 12명'은 A단계 개체 수의 상한으로 읽을 수 있다. 좀비 쪽 A단계 상한은 S2 회색 상자에서 잰다.
- 원형 15개의 애니메이션 비용은 원형 수가 아니라 **자세군 수(다섯 안팎)**가 정한다. [weapons.md](../../design/briefs/weapons.md)를 고칠 일은 아니고 아트 범위를 잡을 때 쓴다.

## 확인 못 한 것

- 42.21 런타임이 B41의 3단 구조를 코드 수준에서 얼마나 유지하는지(공개 소스 없음).
- 좀보이드 캐릭터의 실제 폴리곤 수, 텍스처 해상도, 동시 골격 상한(신뢰할 1차 자료 없음).
