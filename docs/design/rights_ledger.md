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
| Quaternius Universal Animation Library | 3D(동작) | [quaternius.com](https://quaternius.com/packs/universalanimationlibrary.html) | CC0 (같은 문서 69줄) | 사람 동작 후보 | 미정 |
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

### 후보: 트리포 생성 소품 (2026-10-09 트리포 스레드)

| 자산 | 종류 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|---|
| 트리포 맥스 요금제로 만든 소품·건물 조각 | AI 생성(3D) | [tripo3d.ai](https://www.tripo3d.ai/terms) | 약관 2025-07-11 개정판: 유료 회원은 입력·출력 권리를 대체로 가짐, 무료 회원 생성물은 트리포가 권리를 가짐(2026-10-09 요약 도구로 읽음, 원문 다시 열 것) | 유료 기간에만 만든다. 해지 뒤 권리 유지와 공개 저장소 보관은 약관에 문장이 없어 트리포에 글로 묻는다. 원본은 PC에만, 가공한 모델만 빌드에. 모델마다 만든 날, 트리포 모델 버전, 입력 그림 출처, 손본 내역을 적는다. 영수증은 PC에만. 세부: [../art/tripo_pipeline.md](../art/tripo_pipeline.md) 5장 | 미정(Steam AI 공개 필요) |

### AI 생성 렌더 시안

C·B·M 렌더 시안(concept_renders, segment_backdrops, 바깥 눈 점검 주문)과 3D 스레드의 M·T·F 시안(model_renders_20261007.md, train_cars_20261007.md)은 아스트라 울트라 등으로 만든 AI 생성물이고 바탕화면\좀비\에만 있다. 스토어 페이지, 트레일러, 홍보 스크린샷에 시안을 쓰려면 그 전에 이 장에 줄을 만들고 만든 도구, 요금제, 만든 날, 사람이 손본 내역을 적는다. 기본값은 홍보에 시안을 쓰지 않고 실제 게임 화면을 쓰는 것이다.
