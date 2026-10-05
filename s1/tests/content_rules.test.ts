import { describe, expect, it, vi } from 'vitest';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runCli, validateContent } from '../tools/validate';

const profile = JSON.parse(readFileSync(new URL('../fixtures/valid/profile.json', import.meta.url), 'utf8'));
const event = JSON.parse(readFileSync(new URL('../fixtures/valid/event.json', import.meta.url), 'utf8'));
const inspect = (body: string) => validateContent({ ...event, body }, 'event.json');

describe('firearm name regressions', () => {
  it.each([
    'AK', 'AK-47', 'AKM', 'AK-74', 'M16', 'M4', 'AR-15', 'MP5',
    'Mauser', 'Mosin-Nagant', 'Makarov', 'Tokarev', 'Browning', 'Luger', 'Ruger', 'Mossberg',
    'CZ', 'Ceska Zbrojovka', 'Česká zbrojovka', 'Steyr', 'Sako',
  ])('rejects the English name %s in any case', name => {
    for (const spelling of new Set([name, name.toLowerCase(), name.toUpperCase()])) {
      expect(inspect(`${spelling}을 발견했다.`)).toContainEqual(expect.objectContaining({
        path: '/body', code: 'rule.real_firearms', severity: 'error',
      }));
    }
  });

  it.each([
    '에이케이', '에이케이-47', '에이케이엠', '에이케이-74',
    '엠16', '엠4', '에이알-15', '엠피5',
    '엠포', '엠십육', '엠식스틴', '엠피오', '엠피파이브', '에이알 십오', '에이알 피프틴',
    '마우저', '모신나강', '모신 나강', '마카로프', '토카레프', '브라우닝', '루거', '모스버그',
    '체스카 즈브로요브카', '체스카즈브로요브카', '슈타이어', '사코',
  ])('rejects the Korean name %s', name => {
    expect(inspect(`${name}을 발견했다.`)).toContainEqual(expect.objectContaining({
      path: '/body', code: 'rule.real_firearms', severity: 'error',
    }));
  });

  it.each([
    'AK47', 'ak 74', 'M-16', 'M 4', 'AR15', 'MP-5', 'MP 5',
    'Mosin Nagant', '체스카   즈브로요브카', '에이 케이', '엠 16', '에이 알 15', '엠 피 5',
    '엠 포', '엠 식스틴', '엠 피 파이브', '에이 알 십오',
    'ＡＫ－４７', 'ＣＺ', 'ＭＰ５', 'A\u200bKM',
  ])('rejects spacing and normalized spelling variants (%s)', name => {
    expect(inspect(`${name}을 발견했다.`)).toContainEqual(expect.objectContaining({
      code: 'rule.real_firearms', severity: 'error',
    }));
  });

  it.each(['(AK)', '“CZ”', 'Sako의 총', '총은M4다'])('recognizes token boundaries and Korean particles (%s)', body => {
    expect(inspect(body)).toContainEqual(expect.objectContaining({ code: 'rule.real_firearms', severity: 'error' }));
  });

  it.each([
    '추방 명단을 붙였다', '체코 국경', '총을 닦았다', '칸 분리를 명령했다',
    'Czech 국경', 'Czerny의 악보', 'Glockenspiel 소리', 'baking 재료', 'remark 메모',
    'Łak의 장갑', 'Čak의 짐', 'Mauserova의 외투', 'AK_note', 'note_AK', 'CZ_label', 'shipment_M4',
  ])('accepts ordinary wording and larger words (%s)', body => {
    expect(inspect(body)).toEqual([]);
  });

  it('keeps identifiers outside the text rules', () => {
    expect(validateContent({ ...profile, id: 'ak', line: '총을 닦았다' }, 'profile.json')).toEqual([]);
  });
});

describe('unlisted model code warnings', () => {
  it.each(['XX-12', 'Q-9', 'ZZ-9999', 'XX-12A', 'ＸＸ－１２'])('warns without rejecting %s', code => {
    expect(inspect(`${code}를 확인했다.`)).toEqual([expect.objectContaining({
      path: '/body', code: 'rule.firearm_model_code', severity: 'warning',
    })]);
  });

  it.each(['xx-12', 'Xx-12', 'XX12', 'XX-', '12-XX', 'prefixXX-12', 'XX-12suffix', 'prefix_XX-12', 'XX-12_suffix'])(
    'does not warn outside the uppercase hyphenated token pattern (%s)', code => {
      expect(inspect(`${code}를 확인했다.`)).toEqual([]);
    },
  );

  it('keeps known models as errors even when the generic warning also matches', () => {
    expect(inspect('AK-47을 확인했다.')).toContainEqual(expect.objectContaining({
      code: 'rule.real_firearms', severity: 'error',
    }));
  });
});

describe('expulsion and forced transport', () => {
  it.each(['강제 이주', '강제이주', '강제   이주', '강제\t이주', '강제 추방', '강제추방', '강제   추방', '강제\t추방'])(
    'only warns about %s', wording => {
      expect(inspect(`${wording} 명단을 붙였다.`)).toEqual([expect.objectContaining({
        path: '/body', code: 'rule.forced_displacement', severity: 'warning',
      })]);
    },
  );

  it.each(['수용소', '가스실', '절멸', '강제 이송', '강제이송', '강제   이송', '강제\n이송', '강제 수송', '강제수송'])(
    'still rejects %s', wording => {
      expect(inspect(`${wording}을 명령했다.`)).toContainEqual(expect.objectContaining({
        path: '/body', code: 'rule.forced_transport', severity: 'error',
      }));
    },
  );

  it('does not downgrade a forbidden scene that also mentions expulsion', () => {
    const diagnostics = inspect('강제 추방 명단을 수용소로 보냈다.');
    expect(diagnostics).toContainEqual(expect.objectContaining({ code: 'rule.forced_transport', severity: 'error' }));
    expect(diagnostics).toContainEqual(expect.objectContaining({ code: 'rule.forced_displacement', severity: 'warning' }));
  });

  it('returns CLI success and reports all warning-only records', async () => {
    const folder = mkdtempSync(join(tmpdir(), 's1-content-rules-'));
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    try {
      const records = ['강제 이주 명단을 붙였다.', '강제 추방 명단을 붙였다.', 'XX-12를 확인했다.']
        .map((body, index) => ({ ...event, id: `ev_warning_${index}`, body }));
      writeFileSync(join(folder, 'event.json'), JSON.stringify(records));
      expect(await runCli([folder])).toBe(0);
      expect(log).toHaveBeenCalledWith('검사 1파일 / 3항목: 오류 0개, 경고 3개');
    } finally {
      log.mockRestore();
      rmSync(folder, { recursive: true, force: true });
    }
  });
});
