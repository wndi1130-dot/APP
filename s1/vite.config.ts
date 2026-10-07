import { execSync } from 'node:child_process';
import { defineConfig } from 'vitest/config';

// 오류 재현 묶음(src/ui/repro.ts)에 어느 빌드인지 적으려고 커밋 줄임 값을 넣는다.
function gitHead(): string {
  try {
    return execSync('git describe --always --dirty=+', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
  } catch {
    return 'dev';
  }
}

export default defineConfig({
  base: './',
  define: { __BUILD__: JSON.stringify(gitHead()) },
  test: { include: ['tests/**/*.test.ts'] },
});
