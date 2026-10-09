// Node 자체 TypeScript 실행: 별도 번들러·하위 프로세스·설치 없이 로컬 코드만 읽는다.
import { registerHooks } from 'node:module';
import { existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

registerHooks({
  resolve(specifier, context, next) {
    if (specifier.endsWith('.json')) {
      const result = next(specifier, context);
      return { ...result, importAttributes: { type: 'json' } };
    }
    if (specifier.startsWith('.') && context.parentURL?.startsWith('file:')) {
      const url = new URL(specifier, context.parentURL);
      for (const suffix of ['.ts', '/index.ts']) {
        if (existsSync(fileURLToPath(url) + suffix)) return next(url.href + suffix, context);
      }
    }
    return next(specifier, context);
  },
});
const entry = process.argv[2];
if (!entry) throw new Error('실행할 로컬 TypeScript 파일이 필요하다');
process.argv.splice(1, 1);
await import(pathToFileURL(resolve(entry)).href);
