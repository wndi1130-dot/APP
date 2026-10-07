// 작은 DOM 도우미. 화면 뼈대는 프레임워크 없이 상태가 바뀔 때마다 통째로 다시 그린다.
import { plainNumbers } from './plain';

export type Child = Node | string | number | null | undefined | false | readonly Child[];
export type Attrs = Record<string, string | number | boolean | null | undefined>;

function append(parent: Node, child: Child): void {
  if (child === null || child === undefined || child === false) return;
  if (Array.isArray(child)) {
    for (const item of child) append(parent, item);
    return;
  }
  // 글자로 나가는 숫자는 소수점 없이(plain.ts).
  if (child instanceof Node) parent.appendChild(child);
  else parent.appendChild(document.createTextNode(typeof child === 'number' ? String(Number.isInteger(child) ? child : Math.round(child)) : plainNumbers(child as string)));
}

function setAttrs(element: Element, attrs: Attrs | null | undefined): void {
  if (!attrs) return;
  for (const [name, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === false) continue;
    element.setAttribute(name, value === true ? '' : String(value));
  }
}

export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs?: Attrs | null,
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const element = document.createElement(tag);
  setAttrs(element, attrs);
  for (const child of children) append(element, child);
  return element;
}

const SVG_NS = 'http://www.w3.org/2000/svg';

export function s<K extends keyof SVGElementTagNameMap>(
  tag: K,
  attrs?: Attrs | null,
  ...children: Child[]
): SVGElementTagNameMap[K] {
  const element = document.createElementNS(SVG_NS, tag);
  setAttrs(element, attrs);
  for (const child of children) append(element, child);
  return element;
}

/** 여러 조건부 클래스를 하나의 문자열로. */
export function cx(...names: (string | false | null | undefined)[]): string {
  return names.filter(Boolean).join(' ');
}

/** 0~100 값을 막대 너비 문자열로. */
export function pct(value: number, max = 100): string {
  const ratio = max <= 0 ? 0 : Math.min(1, Math.max(0, value / max));
  return `${(ratio * 100).toFixed(2)}%`;
}
