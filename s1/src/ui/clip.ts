// 글 복사. 폰에서 PC의 개발 서버(http://192.168.…)로 열면 보안 문맥이 아니라 navigator.clipboard가 없다.
// 그때는 숨은 글 칸을 골라 document.execCommand('copy')로 복사한다. 둘 다 막히면 false(부른 쪽이 펼치는 칸으로 안내한다).

function legacyCopy(text: string): boolean {
  const doc = globalThis.document;
  if (!doc?.body || typeof doc.execCommand !== 'function') return false;
  const area = doc.createElement('textarea');
  area.value = text;
  area.setAttribute('readonly', '');
  area.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0;font-size:16px';
  doc.body.appendChild(area);
  try {
    area.focus();
    area.select();
    area.setSelectionRange(0, text.length);
    return doc.execCommand('copy');
  } catch {
    return false;
  } finally {
    area.remove();
  }
}

/** 글을 클립보드에 넣는다. 됐으면 true. 단추를 누른 바로 그 자리에서 불러야 한다(브라우저가 사용자 동작을 본다). */
export function copyText(text: string): Promise<boolean> {
  const clip = globalThis.navigator?.clipboard;
  if (clip?.writeText) return clip.writeText(text).then(() => true, () => legacyCopy(text));
  return Promise.resolve(legacyCopy(text));
}
