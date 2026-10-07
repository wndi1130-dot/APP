import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { Profile } from '../tools/gen_profiles.ts';
import {
  S1_ROOT, applyProfileLines, checkLine, fillProfileLines, geminiGenerate, lineTargets, mergeResults, modelUrl, readOverlay, requestBody, runCli,
  type ProfileLineOverlay,
} from '../tools/gen_text.ts';
import { PROMPT_VERSION, buildProfileLineRequest } from '../tools/gen_text_prompt.ts';

const profile = (overrides: Partial<Profile> = {}): Profile => ({
  id: 'p_001', name: '헨리크 마주레크', name_original: 'Henryk Mazurek', gender: 'male', age: 67, community: 'engine',
  origin_tag: 'original', boarding: 'depot', hometown: '볼슈틴, 폴란드', like: '석탄 타는 냄새', dislike: '찬 침상',
  line: '', state: 'alive', ...overrides,
});
const answer = (line: string) => JSON.stringify({ line });
const emptyOverlay = (): ProfileLineOverlay => ({ version: 1, lines: {} });
const scratchDirs: string[] = [];
const scratch = () => {
  mkdirSync(join(S1_ROOT, '.local'), { recursive: true });
  const dir = mkdtempSync(join(S1_ROOT, '.local', 'gen-text-'));
  scratchDirs.push(dir);
  return dir;
};
afterEach(() => { for (const dir of scratchDirs.splice(0)) rmSync(dir, { recursive: true, force: true }); });

describe('요청 조립', () => {
  it('고정 지시에 문체·금기·길이·출력 형식이 들어가고, 데이터는 가이드 3.5가 허락한 필드만 담는다', () => {
    const request = buildProfileLineRequest(profile({ like: '라디오 잡음' }));
    for (const rule of ['좀비', '실제 총기 제조사', '강제 이송', '수용소', '국적이나 민족', '유명 실존 인물', '희망의 불씨', '40자 이내', '{"line": "..."}', '성향, 비밀']) {
      expect(request.system).toContain(rule);
    }
    expect(request.user).toContain('헨리크 마주레크(Henryk Mazurek)');
    expect(request.user).toContain('"좋아하는_것": "라디오 잡음"');
    expect(request.user).toContain('볼슈틴 차고에서 탔다');
    expect(request.user).not.toMatch(/"origin_tag"|"state"|"name_original"|Henryk Mazurek"/u);
    expect(request.promptVersion).toBe(PROMPT_VERSION);
  });
  it('재요청에는 거절 이유가 붙는다', () => {
    expect(buildProfileLineRequest(profile(), ['40자를 넘었다(52자).']).user).toContain('- 40자를 넘었다(52자).');
  });
  it('Gemini 요청 본문은 JSON 응답을 요구하고 키를 담지 않는다', () => {
    const body = JSON.stringify(requestBody(buildProfileLineRequest(profile())));
    expect(body).toContain('"responseMimeType":"application/json"');
    expect(body).toContain('systemInstruction');
    expect(body).not.toMatch(/api.?key/iu);
    expect(modelUrl('models/gemini-test')).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent');
  });
});

describe('검사', () => {
  it('A1 검사기와 한 줄 규칙을 통과한 문장만 받는다', () => {
    expect(checkLine(profile(), answer('식은 삽자루를 장갑 낀 손으로 데운다.'))).toEqual({ line: '식은 삽자루를 장갑 낀 손으로 데운다.', reasons: [] });
    expect(checkLine(profile(), '```json\n{"line": "압력계 유리를 소매로 닦는다."}\n```').line).toBe('압력계 유리를 소매로 닦는다.');
    const cases: [string, RegExp][] = [
      ['그냥 문장', /JSON 하나만/u],
      [answer('가'.repeat(41)), /40자를 넘었다/u],
      [answer('삽을 닦는다. 그리고 잔다.'), /한 문장/u],
      [answer('마주레크는 삽을 닦는다.'), /이름을 문장에/u],
      [answer('67세에도 삽을 닦는다.'), /나이를 문장에/u],
      [answer('"좀비가 온다"며 삽을 닦는다.'), /좀비/u],
      [answer('글록 권총을 베개 밑에 둔다.'), /총기/u],
      [answer('탐욕스러운 눈으로 석탄을 센다.'), /성향/u],
    ];
    for (const [text, reason] of cases) expect(checkLine(profile(), text).reasons.join(' ')).toMatch(reason);
  });
});

describe('생성 흐름', () => {
  it('거절되면 이유를 붙여 다시 요청하고, 통과한 문장만 남긴다', async () => {
    const generate = vi.fn().mockResolvedValueOnce(answer('가'.repeat(45))).mockResolvedValueOnce(answer('식은 삽자루를 데운다.'));
    const [result] = await fillProfileLines([profile()], generate);
    expect(result).toMatchObject({ id: 'p_001', line: '식은 삽자루를 데운다.', attempts: 2 });
    expect(result.rejected).toContain('40자를 넘었다(45자).');
    expect(generate.mock.calls[1][0].user).toContain('40자를 넘었다(45자).');
  });
  it('횟수 제한을 넘으면 저장하지 않고 이유를 남긴다', async () => {
    const generate = vi.fn().mockResolvedValue(answer('좀비 같은 얼굴로 "좀비"라 부른다.'));
    const [result] = await fillProfileLines([profile()], generate, 3);
    expect(generate).toHaveBeenCalledTimes(3);
    expect(result.line).toBeUndefined();
    expect(result.rejected.length).toBeGreaterThan(0);
  });
  it('이미 채운 줄은 대상이 아니고, 한 번에 채울 수는 제한된다', () => {
    const overlay: ProfileLineOverlay = { version: 1, lines: { p_002: { line: '저장된 줄.', model: 'm', prompt_version: PROMPT_VERSION, generated_at: '2026-10-05T00:00:00.000Z' } } };
    const profiles = [profile(), profile({ id: 'p_002' }), profile({ id: 'p_003', line: '손으로 쓴 줄.' }), profile({ id: 'p_004' }), profile({ id: 'p_005' })];
    expect(lineTargets(profiles, overlay, 2).map((item) => item.id)).toEqual(['p_001', 'p_004']);
    expect(applyProfileLines(profiles, overlay).map((item) => item.line)).toEqual(['', '저장된 줄.', '손으로 쓴 줄.', '', '']);
  });
  it('저장할 때 기존 줄을 덮어쓰지 않고 모델·프롬프트 판·시각을 남긴다', () => {
    const before: ProfileLineOverlay = { version: 1, lines: { p_001: { line: '먼저 쓴 줄.', model: 'old', prompt_version: 'v0', generated_at: '2026-01-01T00:00:00.000Z' } } };
    const merged = mergeResults(before, [{ id: 'p_001', line: '새 줄.', attempts: 1, rejected: [] }, { id: 'p_002', line: '둘째 줄.', attempts: 1, rejected: [] }, { id: 'p_003', attempts: 3, rejected: ['x'] }], 'gemini-test', new Date('2026-10-05T12:00:00Z'));
    expect(merged.lines.p_001.line).toBe('먼저 쓴 줄.');
    expect(merged.lines.p_002).toEqual({ line: '둘째 줄.', model: 'gemini-test', prompt_version: PROMPT_VERSION, generated_at: '2026-10-05T12:00:00.000Z' });
    expect(merged.lines.p_003).toBeUndefined();
  });
});

describe('Gemini 호출', () => {
  it('모델 주소와 헤더로 보내고 응답의 글을 꺼낸다', async () => {
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: answer('삽을 닦는다.') }] } }] }), { status: 200 }));
    const generate = geminiGenerate({ apiKey: 'secret-key-123', model: 'gemini-test', fetch: fetchMock as unknown as typeof fetch });
    await expect(generate(buildProfileLineRequest(profile()))).resolves.toBe(answer('삽을 닦는다.'));
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent');
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe('secret-key-123');
    expect(url).not.toContain('secret-key-123');
  });
  it('오류 메시지에 키가 남지 않는다', async () => {
    const leaky = vi.fn(async () => new Response('bad key secret-key-123', { status: 400 }));
    await expect(geminiGenerate({ apiKey: 'secret-key-123', model: 'm', fetch: leaky as unknown as typeof fetch })(buildProfileLineRequest(profile())))
      .rejects.toThrow(/^Gemini 응답 오류 400: bad key \*\*\*$/u);
    const broken = vi.fn(async () => { throw new Error('socket closed for secret-key-123'); });
    await expect(geminiGenerate({ apiKey: 'secret-key-123', model: 'm', fetch: broken as unknown as typeof fetch })(buildProfileLineRequest(profile())))
      .rejects.toThrow(/\*\*\*/u);
  });
});

describe('명령줄', () => {
  const setup = () => {
    const dir = scratch();
    const profilesPath = join(dir, 'profiles.json');
    writeFileSync(profilesPath, JSON.stringify([profile(), profile({ id: 'p_002', name: '파블라 크레이치', age: 41, community: 'tail', boarding: 'refugee', hometown: '브르노, 체코' })]));
    return { dir, profilesPath, outPath: join(dir, 'profile_lines.json') };
  };
  it('드라이런은 키 없이 요청만 보여주고 네트워크를 쓰지 않는다', async () => {
    const { profilesPath, outPath } = setup();
    const logs: string[] = [];
    const fetchMock = vi.fn();
    const code = await runCli(['--dry-run', '--profiles', profilesPath, '--out', outPath, '--limit', '1'], {}, (line) => logs.push(line), fetchMock as unknown as typeof fetch);
    expect(code).toBe(0);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(logs.join('\n')).toContain('<GEMINI_MODEL>');
    expect(logs.join('\n')).toContain('드라이런: 요청 1개');
  });
  it('키나 모델이 없으면 멈추고, --write 없이는 파일을 쓰지 않는다', async () => {
    const { profilesPath, outPath } = setup();
    await expect(runCli(['--profiles', profilesPath, '--out', outPath], {}, () => {})).rejects.toThrow(/GEMINI_API_KEY/u);
    await expect(runCli(['--profiles', profilesPath, '--out', outPath], { GEMINI_API_KEY: 'k' }, () => {})).rejects.toThrow(/모델 이름/u);
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: answer('식은 삽자루를 데운다.') }] } }] })));
    const env = { GEMINI_API_KEY: 'k', GEMINI_MODEL: 'gemini-test' };
    expect(await runCli(['--profiles', profilesPath, '--out', outPath], env, () => {}, fetchMock as unknown as typeof fetch)).toBe(0);
    expect(readOverlay(outPath).lines).toEqual({});
    expect(await runCli(['--profiles', profilesPath, '--out', outPath, '--write'], env, () => {}, fetchMock as unknown as typeof fetch)).toBe(0);
    const saved = JSON.parse(readFileSync(outPath, 'utf8'));
    expect(Object.keys(saved.lines)).toEqual(['p_001', 'p_002']);
    expect(saved.lines.p_001.model).toBe('gemini-test');
  });
  it('출력 파일은 s1/ 안으로 제한하고 잘못된 옵션을 막는다', async () => {
    const { profilesPath } = setup();
    await expect(runCli(['--dry-run', '--profiles', profilesPath, '--out', join(S1_ROOT, '..', 'docs', 'x.json')], {}, () => {})).rejects.toThrow(/s1\//u);
    await expect(runCli(['--limit', '0'], {}, () => {})).rejects.toThrow(/1~200/u);
    await expect(runCli(['--api-key', 'k'], {}, () => {})).rejects.toThrow(/알 수 없는 옵션/u);
  });
});
