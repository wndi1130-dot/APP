// S1b 어두운 길(s1b_dark_path.md 핵심 묶음). 이 파일을 불러오면 카드·안건·훅이 등록된다. 판에 켜는 것은 enableDark.
import './hooks';
import './cards';
import './council';

export { enableDark, hasDark } from './state';
export { migrateDark } from './cases';
export { DARK_CARD_KINDS } from './cards';
export type { DarkState } from './state';
export { darkEnd, logPick, wallDetail, wallLine } from './chronicle';
export { logCardPick } from './h7';
export type { DarkEnd, H7Pick, Testimony, WallName } from './chronicle';
export { B, EXECUTION } from './data';
export { canExtend, canLift, devScene, enterMartial, isMartial, liftMartial } from './martial';
