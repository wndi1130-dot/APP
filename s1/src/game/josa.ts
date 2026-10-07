// 한국어 조사(6.3). 어디서든 부르게 아무것도 가져오지 않는 끝 모듈로 둔다(content.ts가 다시 내보낸다).
// 숫자는 한국어로 읽은 끝소리로 본다(1 일, 3 삼, 6 육, 7 칠, 8 팔, 0 영은 받침, 그중 1·7·8은 ㄹ).
const DIGIT_FINAL: Record<string, 'none' | 'final' | 'rieul'> = {
  0: 'final', 1: 'rieul', 2: 'none', 3: 'final', 4: 'none', 5: 'none', 6: 'final', 7: 'rieul', 8: 'rieul', 9: 'none',
};

function finalOf(word: string): 'none' | 'final' | 'rieul' {
  const ch = [...word.trim()].pop() ?? '';
  const code = ch.charCodeAt(0);
  if (code >= 0xac00 && code <= 0xd7a3) {
    const jong = (code - 0xac00) % 28;
    return jong === 0 ? 'none' : jong === 8 ? 'rieul' : 'final';
  }
  return DIGIT_FINAL[ch] ?? 'none';
}

/** '이/가' 같은 짝에서 받침에 맞는 쪽을 고른다. 으로/로는 ㄹ 받침이면 로. */
export function josa(word: string, pair: string): string {
  const [withFinal, without] = pair.split('/');
  const f = finalOf(word);
  if (withFinal === '으로') return f === 'final' ? '으로' : '로';
  return f === 'none' ? without : withFinal;
}
