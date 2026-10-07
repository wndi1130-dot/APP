# 좀보이드식 그래픽: 어떻게 작동하나

작성: 2026-10-07 · 조사: 웹 GPT 워커(사용자 요청) · 정리: 조사 스레드

좀보이드 화면이 실제로 어떻게 그려지는지, Unity로 비슷하게 만들려면 무엇을 따라 하고 무엇을 버릴지 정리했다. 에셋·도구 목록은 [사용자 조사 브랜치](https://github.com/wndi1130-dot/APP/tree/research/3d-resources-and-art-direction-20261007/ref/art)와 [docs/art/reference_analysis.md](../../art/reference_analysis.md) 10절에 있어서 여기서는 '작동 방식'만 다룬다. 표시는 [README](README.md)를 따른다.

## 한눈에

- 좀보이드는 **2D 등각 타일 배경 위에 3D 캐릭터·좀비·차량을 합성**한다. B41에서 캐릭터를 별도 버퍼에 찍던 방식을 버리고 등각 좌표에 직접 그렸고, 차량은 깊이 버퍼로 가림을 풀었다. [1차]
- B42는 타일에 깊이를 주고 지도를 **8×8 타일 덩어리로 캐시**한다. 그 때문에 시야 원뿔을 타일 조명에서 떼어 냈다. 캐시는 VRAM을 더 쓴다. [1차, 8×8 원문 대조]
- 벽·지붕 자르기는 미관이 아니라 **시야 시스템**이다. 이미 본 좀비는 벽 뒤로 가도 완전히 숨기지 않는다. [1차]
- 워커의 결론: Unity에서는 좀보이드의 낡은 2D 렌더러를 흉내 낼 이유가 없다. **실제 3D 월드 + 고정 직교 카메라 + 방 단위 자르기 + 저해상도 시야 마스크**가 맞다. [제안]

## 1. 2D 타일 + 3D 캐릭터

- 초기 좀보이드는 3D 캐릭터를 화면 밖 버퍼에 그려 2D 스프라이트처럼 붙였다. B41에서 등각 월드 좌표에 직접 그리도록 바꿨고, 그래서 캐릭터와 지도가 같은 좌표계를 쓴다. [1차] [StreamZed III](https://projectzomboid.com/blog/news/2019/10/streamzed-iii/), [Under the Hood](https://projectzomboid.com/blog/news/2017/03/under-the-hood/)
- 차량은 같은 장면에 3D로 그리고 OpenGL 깊이 버퍼로 사람과의 앞뒤를 정한다. [1차] [Clipdoid](https://projectzomboid.com/blog/news/2019/08/clipdoid/)
- B42는 2D 타일에 깊이 정보를 붙여 3D 개체와 픽셀 단위로 겹치게 했다. [1차] [Upcoming Features: Build 42](https://projectzomboid.com/blog/upcoming-features-b42/)(이 링크는 main에 이미 있다)
- 8×8 덩어리 캐시는 2023년 개발 분기 값이다. 지금 42.21에서도 같은지는 확인하지 못했다. [1차] [Knox Event: 30 Years On](https://projectzomboid.com/blog/news/2023/07/knox-event-30-years-on/)

**우리에게**: 3D로 월드를 만들면 깊이 문제를 GPU 깊이 버퍼에 맡길 수 있다. 좀보이드가 B42에서 따로 만든 '가짜 깊이'를 다시 만들 필요가 없다. 이동·충돌·사격은 바닥 평면, 높이는 위아래 축으로 둔다. [제안]

**모바일에서**: Unity Isometric Tilemap은 '개별' 모드면 다른 스프라이트와 순서를 섞을 수 있지만 하나씩 그려서 비싸고, '덩어리' 모드는 빠른 대신 섞기가 제한된다. [1차] [Tilemap Renderer](https://docs.unity.com/en-us/engine/6000.5/manual/unity2d/tilemaps/reference/tilemap-renderer) 그래서 바닥·도로·눈 바닥만 덩어리 레이어로, 벽·문·계단·큰 가구는 저폴리 3D로, 실내 소품은 지금 방과 옆방에서만 켜는 구성을 권했다. [제안]

## 2. 층·지붕·벽 자르기

- 좀보이드는 심즈식 자르기를 키워 왔다. 2017년 글은 이미 확인한 좀비가 벽 뒤에 들어갔다고 렌더러가 완전히 숨기지 않게 고친 사례를 적는다. [1차] [38 IWBUMS n' Roofs](https://projectzomboid.com/blog/news/2017/06/38-iwbums-n-roofs/)
- 공식 모딩 API의 `IsoGridSquare`에 `CutawayNoDepthShader`, `CircleStencilShader`, `roofHideBuilding` 같은 상태가 있다. 자르기가 화면 후처리가 아니라 칸·건물 상태에 묶여 있다는 뜻이다. [1차] [IsoGridSquare](https://projectzomboid.com/modding/zombie/iso/IsoGridSquare.html)
- 차로 빨리 달릴 때는 새 지역의 지붕 자르기와 실내 가구 불러오기를 꺼서 도시 프레임을 올렸다. [1차] [When Dabs Go Wrong](https://projectzomboid.com/blog/news/2019/08/when-dabs-go-wrong/)

**우리에게**: 벽마다 거리로 투명도를 계산하지 말고 `방 → 벽 조각 → 자르기 상태(보임/잘림/숨김)`로 둔다. 디더 셰이더는 상태가 바뀌는 순간 몇 개 벽에만 쓴다. 동료와 '아는 얼굴'처럼 플레이어가 알아야 할 대상은 벽 뒤에서도 실루엣이나 바닥 표시로 남긴다. [제안] 공개 구현: [UniversalRenderingExamples](https://github.com/Unity-Technologies/UniversalRenderingExamples)(가려진 물체 디더), [shaders-wall-cutout](https://github.com/daniel-ilett/shaders-wall-cutout)(이 링크는 사용자 조사 브랜치에도 있다)

## 3. 시야 원뿔과 '안 보이는 곳'의 어둠

- B41은 시야 원뿔이 타일 조명을 바꾸는 방식이었다. B42에서 덩어리 캐시를 쓰자 시야가 바뀔 때마다 캐시가 깨져서, 시야를 조명과 별도 시스템으로 다시 만들었다. 새 시야는 문·커튼에 반응한다. [1차] [Hmm, Upgradez](https://projectzomboid.com/blog/news/2024/01/hmm-upgradez/), [Knox Event](https://projectzomboid.com/blog/news/2023/07/knox-event-30-years-on/)
- 모딩 API에 `canSee`(지금 보임), `couldSee`, `seen`(전에 봄), `darkMulti`(어둠 정도)가 따로 있다. `LosUtil`은 플레이어별 시야 캐시와 두 칸 사이 첫 가림 칸을 찾는다. [1차] [IsoGridSquare.Lighting](https://www.projectzomboid.com/modding/zombie/iso/IsoGridSquare.Lighting.html), [LosUtil](https://www.projectzomboid.com/modding/zombie/iso/LosUtil.html)
- 리그 오브 레전드는 전장의 안개를 CPU에서 128×128로 계산하고 512×512로 늘려 흐리게 그린다. 계산 해상도와 화면 해상도를 나눈 사례다. [1차, 원문 대조] [A Story of Fog and War](https://www.riotgames.com/en/news/story-fog-and-war)

**우리에게**: 게임 시야(CPU의 거친 칸: 지금 보임, 전에 봄, 막힘, 방·문 상태)와 화면 효과(작은 단일 채널 텍스처를 GPU에서 늘려 어둠으로 덮기)를 둘로 나눈다. 플레이어가 칸을 넘거나, 보는 방향이 바뀌거나, 문·창 상태가 바뀔 때만 다시 계산한다. [제안] 128²→512²는 리그의 값이지 우리 권장값이 아니다.

## 4. 밤·실내·광원

- B41은 시간대별 전역 밝기가 있고 실내에서 조금 낮췄다. B42는 햇빛과 광원이 칸을 따라 퍼져서, 창 없는 방은 낮에도 캄캄하다. [1차] [Hmm, Upgradez](https://projectzomboid.com/blog/news/2024/01/hmm-upgradez/)
- B40 때 화면 전체 어둠 셰이더가 손전등·전조등까지 씻어 버려서, 바깥 밝기와 실내 조명을 나누고 건물 마스크로 고쳤다. [1차] [The Darkness](https://projectzomboid.com/blog/news/2018/11/the-darkness/)
- 비슷한 2.5D 생존 게임 Into the Dead: Our Darkest Days는 어두운 실내와 밝은 바깥이 한 화면에 보여서 자동 노출 대신 수동 노출을 쓰고, 그림자 광원에 우선순위와 거리별 해상도를 둔다. PC용 HDRP라 비용은 그대로 가져오면 안 된다. [1차] [Unity 사례](https://unity.com/en/resources/pikpok-into-the-dead-our-darkest-days)

**우리에게**: 칸마다 빛을 퍼뜨리는 대신 `바깥 밝기 × 창 노출 → 방 A × 문 감쇠 → 방 B` 같은 방 그래프로 줄인다. 그림자는 해·달 하나를 중심으로, 손전등·램프·난로는 꼭 필요할 때만 그림자를 켠다. [제안] [URP 성능 설정](https://docs.unity.com/en-us/engine/6000.7/manual/analysis/graphics-performance-profiling/in-urp/optimize-for-better-performance)

## 5. 눈·비·안개

- B40 기상 시스템은 1년 기후와 온난·한랭 전선으로 비·눈·안개·바람을 만든다. [1차] [Build 40 Released](https://projectzomboid.com/blog/news/2018/10/build-40-released/)
- 비·눈·안개가 실내를 덮지 않게 화면 마스크를 만들고, 완전히 닫힌 건물은 기상 효과에서 뺐다. 안개는 뒤에 높이와 불투명도를 가진 층으로 바뀌었다. [1차] [Weather Test](https://projectzomboid.com/blog/news/2018/06/weather-test/), [ExerciZe](https://projectzomboid.com/blog/news/2020/09/exercize/)

**우리에게**: 늘 겨울이고 눈이 정보(발자국, 혈흔)라서 세 층으로 나눈다. 공중(GPU 눈 입자), 표면(눈 덮임 값), 흔적(발자국·혈흔·바퀴 자국을 찍는 작은 렌더 텍스처). 방 마스크를 눈·안개 차단에도 그대로 쓴다. 흔적 텍스처는 지금 정차 지역 주변 크기로만 둔다. [제안] 구현 예: [Custom Render Texture 예제](https://github.com/Unity-Technologies/Graphics/blob/master/Packages/com.unity.shadergraph/Documentation~/Custom-Render-Texture-Example.md)

## 6. 확대·축소

- 옛 줌은 큰 화면 밖 텍스처에 그려 줄이는 방식이라 멀리 볼수록 렌더 타깃이 커졌다. B41에서 투영 기반 줌으로 바꿨다. [1차] [StreamZed III](https://projectzomboid.com/blog/news/2019/10/streamzed-iii/)
- `Core` API에 줌 단계 배열과 최소·최대·다음 줌 메서드가 있다. 42.21의 기본 단계 값은 확인하지 못했다. [1차] [Core](https://projectzomboid.com/modding/zombie/core/Core.html)

**우리에게**: 직교 카메라는 `orthographicSize`만 바꾸면 된다([문서](https://docs.unity.cn/ScriptReference/Camera-orthographicSize.html)). 손가락 줌을 허용해도 안에서는 네 단계(얼굴·장비 / 기본 전투 / 무리 파악 / 실루엣)에 맞춰 메시·애니메이션·그림자 단계를 같이 낮춘다. 멀리 볼수록 화면 안 좀비와 그림자가 급증하므로 텍스처만 낮춰서는 안 된다. [제안]

## 7. 모바일 메모리·드로우콜

- 같은 머티리얼을 나눠 쓰고 SRP Batcher·인스턴싱을 쓴다. 눈 덮인 벽마다 머티리얼을 새로 만들지 않는다. [1차] [드로우콜 최적화](https://docs.unity.cn/Manual/optimizing-draw-calls.html)
- 반복 소품은 아틀라스로 묶는다. [1차] [Sprite Atlas](https://docs.unity.cn/Manual/sprite-atlas.html)
- '확대하면 뭉개져도 된다'는 결정은 밉맵 스트리밍과 같은 방향이다. 카메라에 필요한 밉만 올린다. [제안]
- ASTC를 못 읽는 안드로이드 기기에서는 ASTC 텍스처가 실행 중 RGBA32로 풀려 메모리가 크게 는다. 최소 지원 기기를 먼저 정해야 압축 형식을 고를 수 있다. [1차] [텍스처 압축](https://docs.unity.com/en-us/engine/6000.3/manual/materials-and-shaders/textures/textures-getting-started/texture-compression-formats/texture-choose-format-by-platform)

## 8. 다른 게임

- Darkwood 개발진은 빛과 좁은 시야를 공포·탐색의 핵심으로 설계했다고 직접 말한다. 렌더 내부는 공개하지 않았다. [1차] [PlayStation 블로그](https://blog.playstation.com/2019/05/01/atmospheric-survival-horror-game-darkwood-creeps-to-ps4-may-14/)
- The Last Stand: Aftermath, This Is the Police 계열은 렌더 구조를 확인할 공개 기술 자료를 찾지 못했다.

## 설계에 닿는 점 (결정 아님)

- **열린 질문 10(2D 타일이냐 3D냐)**: 이 조사는 3D 월드 쪽을 가리킨다. 좀보이드가 B42에서 깊이·캐시·시야를 다시 나눈 것은 2D 타일 구조의 비용이었다. [field_unified.md](../../design/briefs/field_unified.md) 0장이 이 조사를 기다리고 있다.
- **사선 시점의 각도**: 좀보이드 카메라의 정확한 각도는 공식 자료에 없다. 흔히 말하는 45°/30°는 넣지 않았다. 시안에서 눈으로 정한다.
- **네 거리 띠와 줌 네 단계**를 같은 화면 기준으로 묶을 수 있다. [weapons.md](../../design/briefs/weapons.md) 거리 띠.

## 확인 못 한 것

- 42.21의 기본 줌 단계, 8×8 덩어리가 지금도 그대로인지.
- 시야 마스크·발자국 텍스처 해상도, 동시 광원 수. 기기와 필드 크기에 따라 달라서 숫자를 넣지 않았다.
