import { afterEach, describe, expect, it, vi } from 'vitest';
import { copyText } from '../../src/ui/clip';

// 글 복사(ui/clip.ts): 클립보드 API가 없는 창(폰에서 http로 연 판)에선 옛 방식으로 복사하고, 둘 다 안 되면 false.

/** execCommand('copy')만 되는 가짜 문서. 복사된 글은 고른 글 칸의 값이다. */
function fakeDoc(execOk: boolean) {
  const seen = { copied: null as string | null, left: 0 };
  let selected: string | null = null;
  const doc = {
    body: { appendChild() { seen.left += 1; } },
    createElement() {
      const area = {
        value: '', style: { cssText: '' },
        setAttribute() {}, focus() {}, setSelectionRange() {},
        select() { selected = area.value; },
        remove() { seen.left -= 1; },
      };
      return area;
    },
    execCommand(cmd: string) { if (cmd === 'copy' && execOk) seen.copied = selected; return execOk; },
  };
  return { doc, seen };
}

describe('글 복사', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('클립보드 API가 있으면 그걸 쓴다', async () => {
    const writeText = vi.fn(() => Promise.resolve());
    vi.stubGlobal('navigator', { clipboard: { writeText } });
    expect(await copyText('기록')).toBe(true);
    expect(writeText).toHaveBeenCalledWith('기록');
  });

  it('클립보드 API가 없으면 숨은 글 칸을 골라 복사하고 칸을 치운다', async () => {
    const { doc, seen } = fakeDoc(true);
    vi.stubGlobal('navigator', {});
    vi.stubGlobal('document', doc);
    expect(await copyText('{"seed":"x"}')).toBe(true);
    expect(seen.copied).toBe('{"seed":"x"}');
    expect(seen.left).toBe(0);
  });

  it('클립보드 API가 거절하면 옛 방식으로 한 번 더 해 본다', async () => {
    const { doc, seen } = fakeDoc(true);
    vi.stubGlobal('navigator', { clipboard: { writeText: () => Promise.reject(new Error('막힘')) } });
    vi.stubGlobal('document', doc);
    expect(await copyText('기록')).toBe(true);
    expect(seen.copied).toBe('기록');
  });

  it('둘 다 안 되면 false다(부른 쪽이 펼치는 칸으로 안내한다)', async () => {
    vi.stubGlobal('navigator', {});
    expect(await copyText('기록')).toBe(false);
    const { doc, seen } = fakeDoc(false);
    vi.stubGlobal('document', doc);
    expect(await copyText('기록')).toBe(false);
    expect(seen.left).toBe(0);
  });
});
