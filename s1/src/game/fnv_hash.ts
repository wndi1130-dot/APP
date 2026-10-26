/** FNV-1a over a JS string's UTF-16 code units (GD train_stop.gd hash_text gives the same). Its own file so
 *  modules omens.ts imports (route_weather.ts) can hash without an import cycle; omens.ts re-exports it. */
export function hash(s: string): number {
  let x = 2166136261;
  for (let i = 0; i < s.length; i += 1) x = Math.imul(x ^ s.charCodeAt(i), 16777619);
  return x >>> 0;
}
