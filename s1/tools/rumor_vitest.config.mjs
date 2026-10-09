// 원본 설정의 시험 대상은 유지하고 캐시는 허용 경로에만 둔다.
export default {
  cacheDir: 'tools/rumor_vite_cache',
  resolve: { preserveSymlinks: true },
  test: { include: ['tests/**/*.test.ts'], pool: 'threads' },
};
