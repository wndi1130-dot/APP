import { describe, expect, it } from 'vitest';
import { settleJosa } from '../../src/game/josa';

describe('두 갈래 조사 풀이', () => {
  it.each([
    ['꼬리칸과(와)의 약속', '꼬리칸과의 약속'],
    ['경비대과(와)의 약속', '경비대와의 약속'],
    ['기관실을(를) 거쳐 열차(으)로', '기관실을 거쳐 열차로'],
    ['길(으)로, 역(으)로', '길로, 역으로'],
    ['앞칸이(가) 둘, 의무진은(는)', '앞칸이 둘, 의무진은'],
    ['3(으)로 1(으)로 2과(와)', '3으로 1로 2와'],
    ['A과(와)', 'A과(와)'],
  ])('S2와 같은 결과를 낸다: %s', (text, expected) => {
    expect(settleJosa(text)).toBe(expected);
  });

  it('성 첫 글자 뒤 점은 앞의 한글 음절로 판단한다', () => {
    expect(settleJosa('호.이(가)')).toBe('호.가');
  });

  it('두 갈래 표기가 없는 글은 그대로 둔다', () => {
    expect(settleJosa('열차가 역으로 들어왔다.')).toBe('열차가 역으로 들어왔다.');
  });

  it('맨 앞의 두 갈래 표기는 그대로 둔다', () => {
    expect(settleJosa('이(가) 둘')).toBe('이(가) 둘');
  });
});
