// 반원 의석 배치. 좌표는 반원의 중심을 원점으로, x는 오른쪽, y는 위쪽이 양수다.
// 그리는 쪽에서 y를 뒤집는다. 집단은 각도 순서(왼쪽 → 오른쪽)로 이어진 쐐기를 차지한다.

export interface HemicycleOptions {
  total: number;
  rows: number;
  innerRadius: number;
  outerRadius: number;
  seatRadius: number;
}

export interface SeatPosition {
  /** 왼쪽 끝부터 0으로 시작하는 각도 순번. */
  order: number;
  row: number;
  x: number;
  y: number;
  /** 라디안. 왼쪽 끝이 π, 오른쪽 끝이 0이다. */
  angle: number;
}

export interface SeatBlock {
  id: string;
  seats: number;
}

/** 화면에 쓰는 기본 배치. 100석, 5줄. 가운데 빈 곳에 찬성 수를 쓴다. 테스트가 겹치지 않음을 확인한다. */
export const DEFAULT_HEMICYCLE: Readonly<HemicycleOptions> = Object.freeze({
  total: 100,
  rows: 5,
  innerRadius: 80,
  outerRadius: 150,
  seatRadius: 7,
});

function assertOptions(options: HemicycleOptions): void {
  const { total, rows, innerRadius, outerRadius, seatRadius } = options;
  if (!Number.isSafeInteger(total) || total < 1) throw new RangeError('의석 수는 1 이상의 정수여야 합니다.');
  if (!Number.isSafeInteger(rows) || rows < 1 || rows > total) throw new RangeError('줄 수는 1 이상, 의석 수 이하의 정수여야 합니다.');
  if (!(innerRadius > 0) || !(outerRadius >= innerRadius)) throw new RangeError('반지름은 0보다 크고 바깥이 안쪽 이상이어야 합니다.');
  if (!(seatRadius > 0)) throw new RangeError('좌석 반지름은 0보다 커야 합니다.');
}

export function rowRadii(options: HemicycleOptions): number[] {
  assertOptions(options);
  const { rows, innerRadius, outerRadius } = options;
  if (rows === 1) return [outerRadius];
  const step = (outerRadius - innerRadius) / (rows - 1);
  return Array.from({ length: rows }, (_, row) => innerRadius + step * row);
}

/** 줄마다 반지름에 비례해 의석을 나눈다. 합은 total이고, 나머지는 큰 순(같으면 바깥 줄)으로 준다. */
export function seatsPerRow(options: HemicycleOptions): number[] {
  const radii = rowRadii(options);
  const sum = radii.reduce((acc, radius) => acc + radius, 0);
  const quotas = radii.map(radius => options.total * radius / sum);
  const counts = quotas.map(quota => Math.max(1, Math.floor(quota)));
  let remaining = options.total - counts.reduce((acc, count) => acc + count, 0);
  const ranked = quotas
    .map((quota, row) => ({ row, remainder: quota - Math.floor(quota) }))
    .sort((a, b) => b.remainder - a.remainder || b.row - a.row);
  for (let index = 0; remaining > 0; index = (index + 1) % ranked.length, remaining -= 1) {
    counts[ranked[index].row] += 1;
  }
  // 줄마다 최소 1석을 줘서 넘친 경우엔 안쪽 줄부터 덜어낸다.
  for (let row = 0; remaining < 0; row = (row + 1) % counts.length) {
    if (counts[row] > 1) {
      counts[row] -= 1;
      remaining += 1;
    }
  }
  return counts;
}

export function layoutHemicycle(options: HemicycleOptions = DEFAULT_HEMICYCLE): SeatPosition[] {
  const radii = rowRadii(options);
  const counts = seatsPerRow(options);
  const seats: Omit<SeatPosition, 'order'>[] = [];
  radii.forEach((radius, row) => {
    const count = counts[row];
    for (let index = 0; index < count; index += 1) {
      const angle = count === 1 ? Math.PI / 2 : Math.PI * (1 - index / (count - 1));
      seats.push({ row, angle, x: radius * Math.cos(angle), y: radius * Math.sin(angle) });
    }
  });
  seats.sort((a, b) => b.angle - a.angle || a.row - b.row);
  return seats.map((seat, order) => ({ ...seat, order }));
}

/** 가장 가까운 두 좌석 중심 사이의 거리. 2 × 좌석 반지름보다 커야 겹치지 않는다. */
export function minSeatDistance(seats: readonly SeatPosition[]): number {
  let min = Infinity;
  for (let i = 0; i < seats.length; i += 1) {
    for (let j = i + 1; j < seats.length; j += 1) {
      const distance = Math.hypot(seats[i].x - seats[j].x, seats[i].y - seats[j].y);
      if (distance < min) min = distance;
    }
  }
  return min;
}

/** 각도 순서의 좌석에 집단을 차례로 채운다. 결과는 좌석 순번마다의 집단 id다. */
export function assignBlocks(seatCount: number, blocks: readonly SeatBlock[]): string[] {
  const total = blocks.reduce((acc, block) => acc + block.seats, 0);
  if (total !== seatCount) throw new RangeError(`집단 의석의 합(${total})이 좌석 수(${seatCount})와 다릅니다.`);
  const result: string[] = [];
  for (const block of blocks) {
    if (!Number.isSafeInteger(block.seats) || block.seats < 0) throw new RangeError('집단 의석은 0 이상의 정수여야 합니다.');
    for (let index = 0; index < block.seats; index += 1) result.push(block.id);
  }
  return result;
}

/** 그리기용 경계 상자(y는 위쪽이 양수). */
export function hemicycleBounds(options: HemicycleOptions = DEFAULT_HEMICYCLE) {
  const pad = options.seatRadius;
  return {
    minX: -options.outerRadius - pad,
    maxX: options.outerRadius + pad,
    minY: -pad,
    maxY: options.outerRadius + pad,
  };
}

/** 두 쐐기 사이의 경계선. 점은 반원 좌표(y 위쪽 양수)이고 안쪽에서 바깥쪽으로 간다. */
export interface WedgeBoundary {
  after: string;
  before: string;
  points: [number, number][];
}

/**
 * 쐐기 경계를 의석 사이 틈으로만 지나가게 잡는다. 줄마다 두 집단 사이의 빈 각도에 점을 찍고,
 * 줄과 줄 사이의 빈 고리를 따라 다음 줄의 점으로 옮겨 간다. 의석 수가 바뀌면 선도 따라 굽는다.
 */
export function wedgeBoundaries(
  options: HemicycleOptions,
  seats: readonly SeatPosition[],
  owners: readonly string[],
): WedgeBoundary[] {
  const radii = rowRadii(options);
  const order: string[] = [];
  for (const id of owners) if (order[order.length - 1] !== id) order.push(id);
  const rank = new Map(order.map((id, index) => [id, index]));
  const rows = radii.map((_, row) => seats.filter(seat => seat.row === row).sort((a, b) => b.angle - a.angle));
  const out: WedgeBoundary[] = [];
  for (let k = 0; k < order.length - 1; k += 1) {
    const angles = rows.map(row => {
      const step = row.length > 1 ? (row[0].angle - row[row.length - 1].angle) / (row.length - 1) : Math.PI;
      const cut = row.filter(seat => (rank.get(owners[seat.order]) ?? 0) <= k).length;
      if (cut === 0) return row[0].angle + step / 2;
      if (cut === row.length) return row[row.length - 1].angle - step / 2;
      return (row[cut - 1].angle + row[cut].angle) / 2;
    });
    const at = (r: number, a: number): [number, number] => [r * Math.cos(a), r * Math.sin(a)];
    const points: [number, number][] = [at(radii[0] - options.seatRadius - 3, angles[0])];
    radii.forEach((radius, row) => {
      points.push(at(radius, angles[row]));
      if (row === radii.length - 1) return;
      const ring = (radius + radii[row + 1]) / 2;
      const from = angles[row];
      const to = angles[row + 1];
      const steps = Math.max(1, Math.ceil(Math.abs(to - from) / 0.03));
      for (let i = 0; i <= steps; i += 1) points.push(at(ring, from + ((to - from) * i) / steps));
    });
    points.push(at(radii[radii.length - 1] + options.seatRadius + 3, angles[angles.length - 1]));
    out.push({ after: order[k], before: order[k + 1], points });
  }
  return out;
}
