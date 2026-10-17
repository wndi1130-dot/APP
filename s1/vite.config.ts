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
  // 로컬 PC는 다른 작업과 함께 돌아 느리므로 시험 한 개 한도를 30초로 둔다. CI는 vitest 기본 5초 그대로.
  test: { include: ['tests/**/*.test.ts'], testTimeout: process.env.CI ? 5000 : 30000 },
});
