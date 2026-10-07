import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, normalize, relative } from 'node:path';
import { describe, expect, it } from 'vitest';

// 실행 시 import 순환 검사(A2 코드 구조 점검 4번). `import type`은 빌드에서 지워지니 빼고 본다.
// 순환이 있으면 모듈이 다 읽히기 전의 값을 쓰게 되어, 부르는 순서에 따라 undefined가 나올 수 있다.

const SRC = join(__dirname, '../../src');

function walk(dir: string): string[] {
  return readdirSync(dir).flatMap(f => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? walk(p) : p.endsWith('.ts') ? [p] : [];
  });
}

function runtimeEdges(files: Set<string>): Map<string, string[]> {
  const edges = new Map<string, string[]>();
  const re = /^\s*(?:import|export)\s+(type\s+)?(?:[^'"]*?\s+from\s+)?['"]([^'"]+)['"]/gm;
  for (const f of files) {
    const out: string[] = [];
    for (const m of readFileSync(f, 'utf8').matchAll(re)) {
      if (m[1] || !m[2].startsWith('.')) continue;
      const base = normalize(join(dirname(f), m[2]));
      const hit = [`${base}.ts`, join(base, 'index.ts'), base].find(c => files.has(c));
      if (hit) out.push(hit);
    }
    edges.set(f, out);
  }
  return edges;
}

/** 강하게 이어진 덩어리(Tarjan) 가운데 둘 이상짜리 = 순환. */
function cycles(edges: Map<string, string[]>): string[][] {
  let n = 0;
  const idx = new Map<string, number>();
  const low = new Map<string, number>();
  const stack: string[] = [];
  const on = new Set<string>();
  const out: string[][] = [];
  const visit = (v: string): void => {
    idx.set(v, n); low.set(v, n); n += 1; stack.push(v); on.add(v);
    for (const w of edges.get(v) ?? []) {
      if (!idx.has(w)) { visit(w); low.set(v, Math.min(low.get(v)!, low.get(w)!)); }
      else if (on.has(w)) low.set(v, Math.min(low.get(v)!, idx.get(w)!));
    }
    if (low.get(v) === idx.get(v)) {
      const comp: string[] = [];
      for (let w = stack.pop()!; ; w = stack.pop()!) { on.delete(w); comp.push(w); if (w === v) break; }
      if (comp.length > 1) out.push(comp.map(c => relative(SRC, c)).sort());
    }
  };
  for (const v of edges.keys()) if (!idx.has(v)) visit(v);
  return out;
}

describe('모듈 구조', () => {
  it('src 안에 실행 시 import 순환이 없다', () => {
    expect(cycles(runtimeEdges(new Set(walk(SRC))))).toEqual([]);
  });

  it('검사기가 순환을 실제로 찾는다', () => {
    const a = join(SRC, 'a.ts');
    const b = join(SRC, 'b.ts');
    expect(cycles(new Map([[a, [b]], [b, [a]]]))).toEqual([['a.ts', 'b.ts']]);
  });
});
