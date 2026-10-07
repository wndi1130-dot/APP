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
| ZapSplat | [라이선스 안내](https://www.zapsplat.com/license-type/standard-license/) | 무료형은 MP3·출처 표시, 유료형은 WAV·무표기 | 기본 1인 라이선스 | 형에 따라 |
| BBC Sound Effects | [안내](https://blog.prosoundeffects.com/how-to-license-bbc-sound-effects-to-use-in-your-commercial-productions) | 상업 이용은 유료 허가 | 쓰려면 사용자에게 묻는다 | 허가 범위 |
| 유료 열차 라이브러리(BOOM TRAINS 등) | sound_music.md 11장 | 상품마다 다름, 사용 인원별 | 쓰려면 사용자에게 묻는다(5단계) | 상품마다 |

### 음악

| 자산 | 출처 | 라이선스 | 조건 | 홍보 |
|---|---|---|---|---|
| 옛 노래의 곡(Es klappert die Mühle 등, sound_music.md 9.3) | 각 곡 출처 링크 | 공공 영역(사이트 표기, 원곡 판본을 다시 확인) | 곡만 쓴다. 편곡과 녹음은 우리가 새로 만들고 따로 줄을 만든다 | 가능 |
| 비발디 '겨울' 곡 | [IMSLP](https://imslp.org/wiki/Winter_(Vivaldi,_Antonio)) | 공공 영역 | 기존 연주 녹음과 현대 판본 악보는 쓰지 않는다 | 가능 |
| Suno Pro 또는 Premier 생성곡 | suno.com | 유료 구독 중 만든 곡만 상업 이용, 해지 뒤에도 유지 | 무료 요금제로 만든 곡은 나중에 유료로 바꿔도 소급되지 않는다. 곡마다 만든 날과 그때 요금제를 적는다 | 약관 확인 필요 |
| Stable Audio 생성곡 | stableaudio.com | 요금제와 상관없이 상업 이용 허용(sound_music.md 9.2 조사 기준) | 쓸 때 약관을 다시 연다 | 약관 확인 필요 |
| AIVA Pro 생성곡 | aiva.ai | Pro는 저작권을 넘겨받음 | 무료·Standard 요금제는 조건이 다르다 | 가능(Pro) |

AI로 만든 음악과 그림은 줄마다 'AI 생성'을 적는다. 사람이 손본 내역(편곡, 녹음, 믹스)도 같이 적는다. AI 생성물은 저작권 보호가 약해서 사람이 고친 부분이 권리의 근거가 되고, Steam은 출시 때 AI 사용을 밝히라고 한다.

## 3. 빌드와 맞춰 보기

플레이 빌드를 낼 때마다 한다.
1. 빌드에 실제로 든 글꼴, 소리, 음악, 그림, 3D 파일 목록을 뽑는다.
2. 목록의 파일마다 1장에 줄이 있는지 본다. 없는 파일은 빌드에서 빼거나 줄을 만든다.
3. 1장에서 '조건'에 표시 문구가 있는 줄이 크레딧과 고지에 모두 들어갔는지 본다.
4. 빌드에서 빠진 파일의 줄은 2장으로 내린다.

지금은 빌드에 남의 소리·글꼴·그림 파일이 없어서 1장의 Godot 고지만 남는다. 파일이 들어오기 시작하면 이 맞춰 보기를 스크립트로 만든다.

## 4. 그림·3D

화면 스레드와 3D 스레드가 위와 같은 칸으로 채운다. 렌더 시안은 바탕화면에만 두고 빌드에 넣지 않으므로 지금은 줄이 없다.
