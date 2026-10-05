// Fills empty text fields with Gemini and keeps only answers that pass the A1 validator.
// Profile lines are saved to generated/profile_lines.json, not data/profiles.json, so the
// A3 generator's output stays byte-reproducible; the game merges them with applyProfileLines.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Profile } from './gen_profiles.ts';
import { PROFILE_LINE_MAX, PROMPT_VERSION, buildProfileLineRequest, type TextRequest } from './gen_text_prompt.ts';
import { countSentences, validateContent } from './validate.ts';

export const S1_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

interface GenTextConfig {
  endpoint: string;
  model: string | undefined;
  maxItems: number;
  maxItemsCeiling: number;
  maxAttempts: number;
  temperature: number;
}
/** The one place to change the model and the cost limits. GEMINI_MODEL or --model sets the model. */
export const GEN_TEXT_CONFIG: Readonly<GenTextConfig> = Object.freeze({
  endpoint: 'https://generativelanguage.googleapis.com/v1beta/models',
  // The content guide names "Gemini 4.0", but its exact API model id is unverified, so there is no default.
  model: undefined,
  maxItems: 5,
  maxItemsCeiling: 200,
  maxAttempts: 3,
  temperature: 0.8,
});

export interface OverlayEntry { line: string; model: string; prompt_version: string; generated_at: string }
export interface ProfileLineOverlay { version: 1; lines: Record<string, OverlayEntry> }
export interface LineResult { id: string; line?: string; attempts: number; rejected: string[] }
export type Generate = (request: TextRequest) => Promise<string>;

export function readOverlay(path: string): ProfileLineOverlay {
  if (!existsSync(path)) return { version: 1, lines: {} };
  const data = JSON.parse(readFileSync(path, 'utf8')) as Partial<ProfileLineOverlay>;
  if (data.version !== 1 || !data.lines || typeof data.lines !== 'object') throw new Error(`${path}: profile_lines 형식이 아닙니다.`);
  return { version: 1, lines: data.lines };
}

/** Profiles whose line is empty and not yet generated, in file order. Filled lines are never overwritten. */
export function lineTargets(profiles: readonly Profile[], overlay: ProfileLineOverlay, limit: number): Profile[] {
  return profiles.filter((profile) => profile.line === '' && !overlay.lines[profile.id]).slice(0, limit);
}

/** What the game reads: generated lines merged over the reproducible A3 data. */
export function applyProfileLines(profiles: readonly Profile[], overlay: ProfileLineOverlay): Profile[] {
  return profiles.map((profile) => profile.line === '' && overlay.lines[profile.id] ? { ...profile, line: overlay.lines[profile.id].line } : profile);
}

/** Parses the model's answer; an empty reason list means the line can be saved. */
export function checkLine(profile: Profile, answer: string): { line?: string; reasons: string[] } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(answer.trim().replace(/^```(?:json)?\s*|\s*```$/gu, ''));
  } catch {
    return { reasons: ['JSON 하나만 내야 한다: {"line": "..."}'] };
  }
  const line = (parsed as { line?: unknown } | null)?.line;
  if (typeof line !== 'string' || !line.trim()) return { reasons: ['line 값이 비어 있거나 문자열이 아니다.'] };
  const text = line.trim();
  const reasons: string[] = [];
  const length = [...text].length;
  if (length > PROFILE_LINE_MAX) reasons.push(`${PROFILE_LINE_MAX}자를 넘었다(${length}자).`);
  if (/[\r\n]/u.test(text)) reasons.push('줄바꿈 없이 한 줄로 써야 한다.');
  if (countSentences(text) > 1) reasons.push('한 문장으로 써야 한다.');
  if (profile.name.split(' ').some((part) => part.length >= 2 && text.includes(part))) reasons.push('이름을 문장에 되풀이했다.');
  if (new RegExp(`${profile.age}\\s*(세|살)`, 'u').test(text)) reasons.push('나이를 문장에 되풀이했다.');
  for (const diagnostic of validateContent({ ...profile, line: text }, 'profiles.json')) {
    if (diagnostic.path.startsWith('/line')) reasons.push(diagnostic.message);
  }
  return reasons.length ? { reasons } : { line: text, reasons };
}

/** Asks for each target in turn; a rejected answer is retried with the reasons attached. */
export async function fillProfileLines(targets: readonly Profile[], generate: Generate, maxAttempts = GEN_TEXT_CONFIG.maxAttempts): Promise<LineResult[]> {
  const results: LineResult[] = [];
  for (const profile of targets) {
    const rejected: string[] = [];
    let line: string | undefined;
    let attempts = 0;
    while (line === undefined && attempts < maxAttempts) {
      attempts += 1;
      const checked = checkLine(profile, await generate(buildProfileLineRequest(profile, rejected)));
      if (checked.line !== undefined) line = checked.line;
      else for (const reason of checked.reasons) if (!rejected.includes(reason)) rejected.push(reason);
    }
    results.push({ id: profile.id, ...(line === undefined ? {} : { line }), attempts, rejected });
  }
  return results;
}

export function requestBody(request: TextRequest, temperature = GEN_TEXT_CONFIG.temperature) {
  return {
    systemInstruction: { parts: [{ text: request.system }] },
    contents: [{ role: 'user', parts: [{ text: request.user }] }],
    generationConfig: { responseMimeType: 'application/json', temperature },
  };
}

export function modelUrl(model: string, endpoint = GEN_TEXT_CONFIG.endpoint): string {
  return `${endpoint}/${encodeURIComponent(model.replace(/^models\//u, ''))}:generateContent`;
}

/** Gemini REST call. The key goes only in the request header and is masked out of every error. */
export function geminiGenerate(options: { apiKey: string; model: string; fetch?: typeof fetch; endpoint?: string; temperature?: number }): Generate {
  const doFetch = options.fetch ?? fetch;
  const mask = (text: string) => text.split(options.apiKey).join('***');
  return async (request) => {
    let response: Response;
    try {
      response = await doFetch(modelUrl(options.model, options.endpoint), {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': options.apiKey },
        body: JSON.stringify(requestBody(request, options.temperature)),
      });
    } catch (error) {
      throw new Error(mask(`Gemini 요청 실패: ${error instanceof Error ? error.message : String(error)}`));
    }
    const text = await response.text();
    if (!response.ok) throw new Error(mask(`Gemini 응답 오류 ${response.status}: ${text.slice(0, 300)}`));
    let data: { candidates?: { content?: { parts?: { text?: string }[] }; finishReason?: string }[] };
    try { data = JSON.parse(text); } catch { throw new Error('Gemini 응답을 JSON으로 읽을 수 없다.'); }
    const answer = data.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('') ?? '';
    if (!answer.trim()) throw new Error(`Gemini 응답에 글이 없다(finishReason: ${data.candidates?.[0]?.finishReason ?? '없음'}).`);
    return answer;
  };
}

export function mergeResults(overlay: ProfileLineOverlay, results: readonly LineResult[], model: string, now = new Date()): ProfileLineOverlay {
  const lines = { ...overlay.lines };
  for (const result of results) {
    if (result.line === undefined || lines[result.id]) continue;
    lines[result.id] = { line: result.line, model, prompt_version: PROMPT_VERSION, generated_at: now.toISOString() };
  }
  return { version: 1, lines: Object.fromEntries(Object.entries(lines).sort(([a], [b]) => a.localeCompare(b))) };
}

function insideS1(path: string): boolean {
  const boundary = relative(S1_ROOT, path);
  return boundary !== '' && !boundary.startsWith('..') && !isAbsolute(boundary);
}

const HELP = `사용법: node s1/tools/gen_text.ts [--dry-run] [--write] [--limit N] [--max-attempts N] [--model 이름] [--profiles 경로] [--out s1/내부경로]
  --dry-run   요청만 만들어 보여준다. 키와 모델 없이 돈다. 네트워크를 쓰지 않는다.
  --write     통과한 문장을 --out 파일에 더한다. 없으면 미리보기만 한다.
  --limit     한 번에 채울 항목 수(기본 ${GEN_TEXT_CONFIG.maxItems}, 최대 ${GEN_TEXT_CONFIG.maxItemsCeiling}).
키는 환경변수 GEMINI_API_KEY로만 받는다. 모델은 GEMINI_MODEL 또는 --model로 정한다.`;

export async function runCli(args: string[], env: NodeJS.ProcessEnv = process.env, log = console.log, fetchImpl?: typeof fetch): Promise<number> {
  let dryRun = false;
  let write = false;
  let limit = GEN_TEXT_CONFIG.maxItems;
  let maxAttempts = GEN_TEXT_CONFIG.maxAttempts;
  let model = env.GEMINI_MODEL?.trim() || GEN_TEXT_CONFIG.model;
  let profilesPath = resolve(S1_ROOT, 'data/profiles.json');
  let outPath = resolve(S1_ROOT, 'generated/profile_lines.json');
  for (let index = 0; index < args.length; index++) {
    const option = args[index];
    if (option === '--help') { log(HELP); return 0; }
    if (option === '--dry-run') { dryRun = true; continue; }
    if (option === '--write') { write = true; continue; }
    const value = args[++index];
    if (!['--limit', '--max-attempts', '--model', '--profiles', '--out'].includes(option)) throw new Error(`알 수 없는 옵션: ${option}`);
    if (!value || value.startsWith('--')) throw new Error(`${option}: 값이 필요합니다.`);
    if (option === '--limit' || option === '--max-attempts') {
      const number = Number(value);
      const ceiling = option === '--limit' ? GEN_TEXT_CONFIG.maxItemsCeiling : 10;
      if (!Number.isInteger(number) || number < 1 || number > ceiling) throw new Error(`${option}: 1~${ceiling} 사이의 정수여야 합니다.`);
      if (option === '--limit') limit = number; else maxAttempts = number;
    }
    if (option === '--model') model = value;
    if (option === '--profiles') profilesPath = resolve(value);
    if (option === '--out') outPath = resolve(value);
  }
  if (!insideS1(outPath)) throw new Error('--out은 s1/ 안이어야 합니다.');
  const profiles = JSON.parse(readFileSync(profilesPath, 'utf8')) as Profile[];
  const overlay = readOverlay(outPath);
  const targets = lineTargets(profiles, overlay, limit);
  if (!targets.length) { log('채울 항목이 없습니다.'); return 0; }

  if (dryRun) {
    for (const profile of targets) {
      const request = buildProfileLineRequest(profile);
      const url = model ? modelUrl(model) : `${GEN_TEXT_CONFIG.endpoint}/<GEMINI_MODEL>:generateContent`;
      log(JSON.stringify({ id: request.id, url, body: requestBody(request) }, null, 2));
    }
    log(`드라이런: 요청 ${targets.length}개를 만들었고 보내지 않았습니다.`);
    return 0;
  }
  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY 환경변수가 필요합니다. 키를 저장소나 명령줄에 쓰지 마세요.');
  if (!model) throw new Error('모델 이름이 필요합니다. GEMINI_MODEL 환경변수나 --model로 정하세요.');
  const results = await fillProfileLines(targets, geminiGenerate({ apiKey, model, fetch: fetchImpl }), maxAttempts);
  const byId = new Map(targets.map((profile) => [profile.id, profile]));
  for (const result of results) {
    const name = byId.get(result.id)!.name;
    log(result.line === undefined
      ? `${result.id} ${name}: 실패(${result.attempts}회) - ${result.rejected.join(' / ')}`
      : `${result.id} ${name}: ${result.line}`);
  }
  if (write) {
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, `${JSON.stringify(mergeResults(overlay, results, model), null, 2)}\n`, 'utf8');
    log(`저장: ${relative(S1_ROOT, outPath)}`);
  } else log('미리보기만 했습니다. 저장하려면 --write를 붙이세요.');
  return results.every((result) => result.line !== undefined) ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  runCli(process.argv.slice(2)).then((code) => { process.exitCode = code; }, (error: unknown) => {
    console.error(`문장 생성 실패: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  });
}
