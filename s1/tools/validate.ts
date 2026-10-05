import { readdir, readFile, stat } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { basename, dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv2020 from 'ajv/dist/2020.js';
import type { AnySchema, ErrorObject } from 'ajv';

export const contentKinds = [
  'profile', 'character', 'secret', 'event', 'law', 'deal', 'place', 'chronicle',
] as const;
export type ContentKind = (typeof contentKinds)[number];
type Severity = 'error' | 'warning';
export interface Diagnostic {
  file: string;
  path: string;
  severity: Severity;
  code: string;
  message: string;
}
export interface ValidationResult {
  files: number;
  records: number;
  diagnostics: Diagnostic[];
  valid: boolean;
}
interface Rule {
  id: string;
  severity: Severity;
  scope: 'text' | 'dialogue';
  message: string;
  terms: string[];
  patterns: string[];
  pattern_flags?: 'u' | 'iu';
}
interface ContentRules {
  text_fields: Record<ContentKind, string[]>;
  dialogue_fields: Partial<Record<ContentKind, string[]>>;
  sentence_limits: Partial<Record<ContentKind, { path: string; max: number }[]>>;
  rules: Rule[];
}

const schemaDirectory = fileURLToPath(new URL('../schema/', import.meta.url));
const ajv = new Ajv2020({ allErrors: true, strict: true, allowUnionTypes: true });
for (const name of ['common', 'effects', ...contentKinds]) {
  const schema = JSON.parse(readFileSync(join(schemaDirectory, `${name}.schema.json`), 'utf8')) as AnySchema;
  ajv.addSchema(schema);
}
const validators = Object.fromEntries(contentKinds.map(kind => {
  const validator = ajv.getSchema(`urn:s1:schema:${kind}`);
  if (!validator) throw new Error(`스키마를 찾을 수 없습니다: ${kind}`);
  return [kind, validator];
}));
const rules = JSON.parse(readFileSync(join(schemaDirectory, 'content_rules.json'), 'utf8')) as ContentRules;
const compiledRules = rules.rules.map(rule => ({
  ...rule,
  expressions: rule.patterns.map(pattern => new RegExp(pattern, rule.pattern_flags ?? 'iu')),
}));
const segmenter = new Intl.Segmenter('ko', { granularity: 'sentence' });
const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const isKind = (value: unknown): value is ContentKind =>
  typeof value === 'string' && contentKinds.includes(value as ContentKind);
const escapePointer = (value: string) => value.replace(/~/g, '~0').replace(/\//g, '~1');

export function countSentences(value: string): number {
  return value.split(/\r?\n/u).reduce((count, line) => count +
    [...segmenter.segment(line)].filter(part => /[\p{L}\p{N}]/u.test(part.segment)).length, 0);
}

function selectPaths(value: unknown, pattern: string): { path: string; value: unknown }[] {
  const parts = pattern.split('/').slice(1);
  const visit = (current: unknown, index: number, path: string): { path: string; value: unknown }[] => {
    if (index === parts.length) return [{ path, value: current }];
    const part = parts[index];
    if (part === '*') {
      return Array.isArray(current)
        ? current.flatMap((item, itemIndex) => visit(item, index + 1, `${path}/${itemIndex}`)) : [];
    }
    return isRecord(current) && Object.hasOwn(current, part)
      ? visit(current[part], index + 1, `${path}/${escapePointer(part)}`) : [];
  };
  return visit(value, 0, '');
}

function inferKind(value: Record<string, unknown>, file: string): ContentKind | undefined {
  if (Object.hasOwn(value, 'content_type')) return isKind(value.content_type) ? value.content_type : undefined;
  const names = [basename(file, extname(file)), basename(dirname(file))];
  for (const name of names) {
    const tokens = name.toLowerCase().split(/[._-]/u);
    const hint = contentKinds.find(kind => tokens.includes(kind) || tokens.includes(`${kind}s`));
    if (hint) return hint;
  }
  const signatures: [ContentKind, string[]][] = [
    ['character', ['role', 'bio', 'trait']], ['event', ['choices', 'body', 'stage']],
    ['law', ['opens_when', 'stances', 'preview']], ['deal', ['ask', 'gives', 'deadline']],
    ['place', ['loot', 'moral_cards', 'risk']], ['chronicle', ['who', 'what', 'template']],
    ['secret', ['severity', 'proof', 'sources']], ['profile', ['name', 'age', 'boarding']],
  ];
  return signatures.find(([, keys]) => keys.some(key => Object.hasOwn(value, key)))?.[0];
}

function formatSchemaError(error: ErrorObject): string {
  const params = error.params;
  switch (error.keyword) {
    case 'required': return `필수 항목 ${params.missingProperty}이(가) 없습니다.`;
    case 'additionalProperties': return `허용하지 않는 항목 ${params.additionalProperty}이(가) 있습니다.`;
    case 'unevaluatedProperties': return `허용하지 않는 항목 ${params.unevaluatedProperty}이(가) 있습니다.`;
    case 'type': return `값의 형식은 ${params.type}이어야 합니다.`;
    case 'enum': return `허용된 값: ${(params.allowedValues as unknown[]).join(', ')}.`;
    case 'const': return `값은 ${String(params.allowedValue)}이어야 합니다.`;
    case 'minimum': return `값은 ${params.limit} 이상이어야 합니다.`;
    case 'maximum': return `값은 ${params.limit} 이하여야 합니다.`;
    case 'minItems': return `항목이 ${params.limit}개 이상이어야 합니다.`;
    case 'maxItems': return `항목이 ${params.limit}개 이하여야 합니다.`;
    case 'minLength': return `글자 수가 ${params.limit}자 이상이어야 합니다.`;
    case 'maxLength': return `글자 수가 ${params.limit}자 이하여야 합니다.`;
    case 'pattern': return `문자열이 형식 ${params.pattern}에 맞아야 합니다.`;
    case 'oneOf': return '허용된 형식 중 정확히 하나에 맞아야 합니다.';
    case 'false schema': return '이 위치에 항목을 더 넣을 수 없습니다.';
    default: return `스키마 조건 ${error.keyword}을(를) 충족해야 합니다.`;
  }
}

function schemaDiagnostics(errors: ErrorObject[], file: string, prefix: string): Diagnostic[] {
  // Suppress errors about arguments belonging to a different effect/condition type.
  const rejected = errors.flatMap(error => {
    const branch = error.schemaPath.match(/^(.*\/oneOf\/\d+)\//u)?.[1];
    return branch && ['const', 'enum'].includes(error.keyword) && error.instancePath.endsWith('/type')
      ? [{ branch, root: error.instancePath.slice(0, -5) }] : [];
  });
  const selected = errors.filter(error => {
    const branch = error.schemaPath.match(/^(.*\/oneOf\/\d+)\//u)?.[1];
    const unrelated = rejected.some(item => item.branch === branch &&
      (error.instancePath === item.root || error.instancePath.startsWith(`${item.root}/`)));
    return !unrelated || error.instancePath.endsWith('/type');
  });
  const typeEnums = new Map<string, unknown[]>();
  for (const error of selected) {
    if (['enum', 'const'].includes(error.keyword) && error.instancePath.endsWith('/type')) {
      const values = typeEnums.get(error.instancePath) ?? [];
      values.push(...(error.keyword === 'enum' ? error.params.allowedValues : [error.params.allowedValue]));
      typeEnums.set(error.instancePath, values);
    }
  }
  const diagnostics = selected.filter(error => !typeEnums.has(error.instancePath)).map(error => {
    const property = error.params.missingProperty ?? error.params.additionalProperty ?? error.params.unevaluatedProperty;
    return {
      file, path: `${prefix}${error.instancePath}${property ? `/${escapePointer(String(property))}` : ''}` || '/',
      severity: 'error' as const, code: `schema.${error.keyword}`, message: formatSchemaError(error),
    };
  });
  for (const [path, values] of typeEnums) {
    // A successful branch makes the type legal; retain only its argument errors.
    const root = path.slice(0, -5);
    const alternatives = errors.filter(error => error.schemaPath.includes('/oneOf/') &&
      (error.instancePath === root || error.instancePath.startsWith(`${root}/`)));
    const branches = new Set(alternatives.map(error => error.schemaPath.match(/^(.*\/oneOf\/\d+)\//u)?.[1]).filter(Boolean));
    if ([...branches].some(branch => !rejected.some(item => item.branch === branch && item.root === root))) continue;
    diagnostics.push({ file, path: `${prefix}${path}`, severity: 'error', code: 'schema.enum', message: `허용된 type 값: ${[...new Set(values)].join(', ')}.` });
  }
  return [...new Map(diagnostics.map(item => [`${item.path}|${item.code}|${item.message}`, item])).values()];
}

export function validateContent(value: unknown, file = 'content.json', prefix = ''): Diagnostic[] {
  if (!isRecord(value)) return [{ file, path: prefix || '/', severity: 'error', code: 'content.object', message: '콘텐츠 항목은 JSON 객체여야 합니다.' }];
  const kind = inferKind(value, file);
  if (!kind) return [{ file, path: Object.hasOwn(value, 'content_type') ? `${prefix}/content_type` : prefix || '/', severity: 'error', code: 'content.kind', message: `콘텐츠 종류를 알 수 없습니다. content_type에 ${contentKinds.join(', ')} 중 하나를 넣거나 종류에 맞는 파일명을 쓰세요.` }];
  const validator = validators[kind];
  const diagnostics: Diagnostic[] = validator(value) ? [] : schemaDiagnostics(validator.errors ?? [], file, prefix);
  const add = (path: string, severity: Severity, code: string, message: string) =>
    diagnostics.push({ file, path: `${prefix}${path}` || '/', severity, code, message });
  for (const limit of rules.sentence_limits[kind] ?? []) {
    for (const field of selectPaths(value, limit.path)) {
      if (typeof field.value !== 'string') continue;
      const count = countSentences(field.value);
      if (count > limit.max) add(field.path, 'error', 'length.sentences', `문장은 ${limit.max}개 이하여야 합니다. 현재 ${count}문장입니다.`);
    }
  }
  const dialoguePaths = new Set((rules.dialogue_fields[kind] ?? []).flatMap(pattern => selectPaths(value, pattern).map(field => field.path)));
  for (const pattern of rules.text_fields[kind]) {
    for (const field of selectPaths(value, pattern)) {
      if (typeof field.value !== 'string') continue;
      const normalized = field.value.normalize('NFKC').replace(/\p{Cf}/gu, '');
      const dialogue = dialoguePaths.has(field.path) ? normalized
        : [...normalized.matchAll(/"[^"]*"|“[^”]*”|'[^']*'|‘[^’]*’|「[^」]*」/gu)].map(match => match[0]).join('\n');
      for (const rule of compiledRules) {
        const text = rule.scope === 'dialogue' ? dialogue : normalized;
        const term = rule.terms.find(candidate => text.toLocaleLowerCase('ko').includes(candidate.toLocaleLowerCase('ko')));
        const match = rule.expressions.map(expression => expression.exec(text)).find(Boolean)?.[0];
        if (term || match) add(field.path, rule.severity, `rule.${rule.id}`, `${rule.message} 발견한 표현: ${term ?? match}`);
      }
    }
  }
  for (const key of ['trigger', 'opens_when']) {
    if (!Array.isArray(value[key])) continue;
    value[key].forEach((condition, index) => {
      if (isRecord(condition) && condition.type === 'segment' && typeof condition.min === 'number' && typeof condition.max === 'number' && condition.min > condition.max) {
        add(`/${key}/${index}/max`, 'error', 'condition.range', '구간 범위의 끝은 시작 이상이어야 합니다.');
      }
    });
  }
  return diagnostics;
}

export async function validateFolder(folder: string): Promise<ValidationResult> {
  const result: ValidationResult = { files: 0, records: 0, diagnostics: [], valid: false };
  const directory = resolve(folder);
  const ioError = (file: string, message: string) => result.diagnostics.push({ file, path: '/', severity: 'error', code: 'input.io', message });
  const visit = async (current: string) => {
    let entries;
    try { entries = await readdir(current, { withFileTypes: true }); }
    catch { ioError(current, '폴더를 읽을 수 없습니다. 경로와 읽기 권한을 확인하세요.'); return; }
    for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name, 'en'))) {
      const file = join(current, entry.name);
      if (entry.isSymbolicLink()) {
        ioError(file, '검사 범위를 벗어날 수 있는 심볼릭 링크는 읽지 않습니다. 실제 데이터 폴더를 지정하세요.');
      } else if (entry.isDirectory()) {
        await visit(file);
      } else if (entry.isFile() && extname(entry.name).toLowerCase() === '.json') {
        result.files += 1;
        let data: unknown;
        try { data = JSON.parse((await readFile(file, 'utf8')).replace(/^\uFEFF/u, '')); }
        catch (error) {
          result.diagnostics.push({ file, path: '/', severity: 'error', code: 'input.json', message: `JSON을 읽거나 해석할 수 없습니다: ${error instanceof Error ? error.message : String(error)}` });
          continue;
        }
        const items = Array.isArray(data) ? data : [data];
        if (items.length === 0) result.diagnostics.push({ file, path: '/', severity: 'error', code: 'input.empty', message: '검사할 콘텐츠 항목이 없는 빈 배열입니다.' });
        items.forEach((item, index) => {
          result.records += 1;
          result.diagnostics.push(...validateContent(item, file, Array.isArray(data) ? `/${index}` : ''));
        });
      }
    }
  };
  try {
    if (!(await stat(directory)).isDirectory()) ioError(directory, 'JSON 파일이 들어 있는 폴더를 지정해야 합니다.');
    else await visit(directory);
  } catch { ioError(directory, '검사 폴더를 찾거나 읽을 수 없습니다. 경로를 확인하세요.'); }
  if (result.files === 0 && result.diagnostics.length === 0) result.diagnostics.push({ file: directory, path: '/', severity: 'error', code: 'input.empty', message: '검사할 JSON 파일이 없습니다.' });
  result.valid = !result.diagnostics.some(item => item.severity === 'error');
  return result;
}

export async function runCli(args: string[]): Promise<number> {
  if (args.length !== 1 || ['--help', '-h'].includes(args[0])) {
    console.log('사용법: npm run validate -- <JSON 데이터 폴더>');
    return args.length === 1 ? 0 : 2;
  }
  const result = await validateFolder(args[0]);
  for (const item of result.diagnostics) {
    console.log(`${item.severity === 'error' ? '오류' : '경고'} ${item.file}:${item.path} [${item.code}] ${item.message}`);
  }
  const errors = result.diagnostics.filter(item => item.severity === 'error').length;
  const warnings = result.diagnostics.length - errors;
  console.log(`검사 ${result.files}파일 / ${result.records}항목: 오류 ${errors}개, 경고 ${warnings}개`);
  return result.valid ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await runCli(process.argv.slice(2));
}
