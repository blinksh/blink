// some useful refs
// https://www.w3.org/TR/uievents-code/#key-function-section
// https://github.com/chromium/hterm/blob/master/doc/ControlSequences.md

const CANCEL = Symbol('CANCEL');
const DEFAULT = Symbol('DEFAULT');
const PASS = Symbol('PASS');
const STRIP = Symbol('STRIP');

export type KeyInfoType = {
  key: string,
  code: string,
  keyCode: number,
  src?: string,
};

export type KeyDownType = KeyInfoType & {
  alt: boolean,
  ctrl: boolean,
  meta: boolean,
  shift: boolean,
};

type KeyActionFunc = (e: KeyDownType, def: KeyDefType) => KeyActionType;
export type KeyActionType =
  | KeyActionFunc
  | typeof CANCEL
  | typeof DEFAULT
  | typeof PASS
  | typeof STRIP
  | string;

export const KBActions = {
  CANCEL,
  DEFAULT,
  PASS,
  STRIP,
};

type OpType =
  | 'out'
  | 'selection'
  | 'ime'
  | 'mods'
  | 'ready'
  | 'command'
  | 'capture'
  | 'guard-ime-on'
  | 'guard-ime-off'
  | 'zoom-in'
  | 'zoom-out'
  | 'zoom-reset';

export function op(op: OpType, args: {}) {
  let message = {...args, op};
  // @ts-ignore
  window.webkit.messageHandlers._kb.postMessage(message);
}

const ESC = '\x1b'; // Escape
const CSI = '\x1b['; // Command Start Inidicator
const SS3 = '\x1bO'; // Single-Shift Three
const DEL = '\x7f'; // Delete

const ctl = (ch: string) => String.fromCharCode(ch.charCodeAt(0) - 64);

type KeyDefType = {
  keyCode: number,
  keyCap: string, // two chars string like 'aA' or [UNPRINTABLE]

  normal: KeyActionType,
  ctrl: KeyActionType,
  alt: KeyActionType,
  meta: KeyActionType,
};

const _unknownKeyDef: KeyDefType = {
  keyCode: 0,
  keyCap: '[Unidentified]',
  normal: PASS,
  ctrl: PASS,
  alt: PASS,
  meta: PASS,
};

export interface IKeyboard {
  hasSelection: boolean;
}

export default class KeyMap {
  _defs: {[index: number]: KeyDefType | undefined} = {};
  _reverseDefs: {[index: string]: KeyDefType | undefined} = {};
  _keyboard: IKeyboard;

  constructor(keyboard: IKeyboard) {
    this._keyboard = keyboard;
    this.reset();
  }

  getKeyDef(keyCode: number): KeyDefType {
    var keyDef = this._defs[keyCode];
    if (keyDef) {
      return keyDef;
    }
    // If this key hasn't been explicitly registered, fall back to the unknown
    // key mapping (keyCode == 0), and then automatically register it to avoid
    // any further warnings here.
    console.warn(`No definition for (keyCode ${keyCode})`);
    keyDef = _unknownKeyDef;
    this.addKeyDef(keyCode, keyDef);

    return keyDef;
  }

  addKeyDef(keyCode: number, def: KeyDefType) {
    if (keyCode in this._defs) {
      console.warn('Dup keyCode: ', keyCode);
    }

    this._defs[keyCode] = def;

    //def.keyCap[0]
    let nonPrintable = /^\[\w+\]$/.test(def.keyCap);
    if (nonPrintable) {
      let key = def.keyCap.replace(/\W/g, '');
      this._reverseDefs[key] = def;
    } else {
      var letter = def.keyCap[0];
      this._reverseDefs[letter] = def;
      if (/0-9/.test(letter)) {
        this._reverseDefs['Digit' + letter] = def;
      } else if (/[a-z]/.test(letter)) {
        this._reverseDefs['Key' + letter.toUpperCase()] = def;
      }
    }
  }

  // prettier-ignore
  reset() {
    this._defs = {};

    const resolve = (action: KeyActionType, e: KeyDownType, k: KeyDefType): KeyActionType => {
      if (typeof action == 'function') {
        return action.call(this, e, k)
      }
      return action
    }

    const mod = (a: KeyActionType, b: KeyActionType) => (e: KeyDownType, k: KeyDefType) => {
      let action = !(e.shift || e.ctrl || e.alt || e.meta) ? a : b;
      return resolve(action, e, k);
    }
    const sh = (a: KeyActionType, b: KeyActionType) => (e: KeyDownType, k: KeyDefType) => {
      let action = !e.shift ? a : b;
      e.shift = false;
      return resolve(action, e, k);
    }
    const bs = (a: KeyActionType, b: KeyActionType) => a
    const alt = (a: KeyActionType, b: KeyActionType) => (e: KeyDownType, k: KeyDefType) => {
      let action = e.alt ? a : b;
      return resolve(action, e, k);
    }
    const ak = (a: KeyActionType, b: KeyActionType) => a;
    const ac = (a: KeyActionType, b: KeyActionType) => b;

    // if in selection mode, that handle with this._onSel
    const sl = (a: KeyActionType) => (e: KeyDownType, k: KeyDefType) => {
      let action = this._keyboard.hasSelection ? this._onSel : a
      return resolve(action, e, k);
    }

    const add = (def: KeyDefType) => this.addKeyDef(def.keyCode, def);


    //add({ keyCode: 0, keyCap: '[UNKNOWN]', normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });
    add(_unknownKeyDef)

    // first row
    add({ keyCode: 27,  keyCap: '[Escape]', normal: sl(ESC),                   ctrl: DEFAULT, alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 112, keyCap: '[F1]',     normal: mod(SS3 + 'P', CSI + 'P'), ctrl: DEFAULT, alt: CSI + '23~', meta: DEFAULT });
    add({ keyCode: 113, keyCap: '[F2]',     normal: mod(SS3 + 'Q', CSI + 'Q'), ctrl: DEFAULT, alt: CSI + '24~', meta: DEFAULT });
    add({ keyCode: 114, keyCap: '[F3]',     normal: mod(SS3 + 'R', CSI + 'R'), ctrl: DEFAULT, alt: CSI + '25~', meta: DEFAULT });
    add({ keyCode: 115, keyCap: '[F4]',     normal: mod(SS3 + 'S', CSI + 'S'), ctrl: DEFAULT, alt: CSI + '26~', meta: DEFAULT });
    add({ keyCode: 116, keyCap: '[F5]',     normal: CSI + '15~',               ctrl: DEFAULT, alt: CSI + '28~', meta: DEFAULT });
    add({ keyCode: 117, keyCap: '[F6]',     normal: CSI + '17~',               ctrl: DEFAULT, alt: CSI + '29~', meta: DEFAULT });
    add({ keyCode: 118, keyCap: '[F7]',     normal: CSI + '18~',               ctrl: DEFAULT, alt: CSI + '31~', meta: DEFAULT });
    add({ keyCode: 119, keyCap: '[F8]',     normal: CSI + '19~',               ctrl: DEFAULT, alt: CSI + '32~', meta: DEFAULT });
    add({ keyCode: 120, keyCap: '[F9]',     normal: CSI + '20~',               ctrl: DEFAULT, alt: CSI + '33~', meta: DEFAULT });
    add({ keyCode: 121, keyCap: '[F10]',    normal: CSI + '21~',               ctrl: DEFAULT, alt: CSI + '34~', meta: DEFAULT });
    add({ keyCode: 122, keyCap: '[F11]',    normal: CSI + '23~',               ctrl: DEFAULT, alt: CSI + '42~', meta: DEFAULT });
    add({ keyCode: 123, keyCap: '[F12]',    normal: CSI + '24~',               ctrl: DEFAULT, alt: CSI + '43~', meta: DEFAULT });

    const onCtrlNum = this._onCtrlNum
    const onAltNum = this._onAltNum
    const onMetaNum = this._onMetaNum
    const onZoom = this._onZoom
    
    // second row
    add({ keyCode: 192,  keyCap: '`~',          normal: DEFAULT,       ctrl: sh(ctl('@'), ctl('^')), alt: DEFAULT,  meta: PASS });
    add({ keyCode: 49,   keyCap: '1!',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 50,   keyCap: '2@',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 51,   keyCap: '3#',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 52,   keyCap: '4$',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 53,   keyCap: '5%',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 54,   keyCap: '6^',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 55,   keyCap: '7&',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 56,   keyCap: '8*',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 57,   keyCap: '9(',          normal: DEFAULT,       ctrl: onCtrlNum,              alt: onAltNum, meta: onMetaNum });
    add({ keyCode: 48,   keyCap: '0)',          normal: DEFAULT,       ctrl: onZoom,                 alt: onAltNum, meta: onZoom });
    add({ keyCode: 189,  keyCap: '-_',          normal: DEFAULT,       ctrl: sh(onZoom, ctl('_')),   alt: DEFAULT,  meta: onZoom });
    add({ keyCode: 187,  keyCap: '=+',          normal: DEFAULT,       ctrl: onZoom,                 alt: DEFAULT,  meta: onZoom });
    add({ keyCode: 8,    keyCap: '[Backspace]', normal: bs(DEL, '\b'), ctrl: bs('\b', DEL),          alt: DEFAULT,  meta: DEFAULT });
    
    // third row
    add({ keyCode: 9,   keyCap: '[Tab]', normal: sh('\t', CSI + 'Z'), ctrl: STRIP,        alt: PASS,        meta: DEFAULT });
    add({ keyCode: 81,  keyCap: 'qQ',    normal: DEFAULT,             ctrl: ctl('Q'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 87,  keyCap: 'wW',    normal: sl(DEFAULT),         ctrl: ctl('W'),     alt: sl(DEFAULT), meta: DEFAULT });
    add({ keyCode: 69,  keyCap: 'eE',    normal: DEFAULT,             ctrl: ctl('E'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 82,  keyCap: 'rR',    normal: DEFAULT,             ctrl: ctl('R'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 84,  keyCap: 'tT',    normal: DEFAULT,             ctrl: ctl('T'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 89,  keyCap: 'yY',    normal: sl(DEFAULT),         ctrl: ctl('Y'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 85,  keyCap: 'uU',    normal: DEFAULT,             ctrl: ctl('U'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 73,  keyCap: 'iI',    normal: DEFAULT,             ctrl: ctl('I'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 79,  keyCap: 'oO',    normal: sl(DEFAULT),         ctrl: ctl('O'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 80,  keyCap: 'pP',    normal: sl(DEFAULT),         ctrl: sl(ctl('P')), alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 219, keyCap: '[{',    normal: DEFAULT,             ctrl: ctl('['),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 221, keyCap: ']}',    normal: DEFAULT,             ctrl: ctl(']'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 220, keyCap: '\\|',   normal: DEFAULT,             ctrl: ctl('\\'),    alt: DEFAULT,     meta: DEFAULT });

    // fourth row
    add({ keyCode: 20,  keyCap: '[CapsLock]', normal: PASS,        ctrl: PASS,         alt: PASS,        meta: DEFAULT });
    add({ keyCode: 65,  keyCap: 'aA',         normal: DEFAULT,     ctrl: ctl('A'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 83,  keyCap: 'sS',         normal: DEFAULT,     ctrl: ctl('S'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 68,  keyCap: 'dD',         normal: DEFAULT,     ctrl: ctl('D'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 70,  keyCap: 'fF',         normal: DEFAULT,     ctrl: sl(ctl('F')), alt: sl(DEFAULT), meta: DEFAULT });
    add({ keyCode: 71,  keyCap: 'gG',         normal: DEFAULT,     ctrl: ctl('G'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 72,  keyCap: 'hH',         normal: sl(DEFAULT), ctrl: ctl('H'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 74,  keyCap: 'jJ',         normal: sl(DEFAULT), ctrl: ctl('J'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 75,  keyCap: 'kK',         normal: sl(DEFAULT), ctrl: ctl('K'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 76,  keyCap: 'lL',         normal: sl(DEFAULT), ctrl: ctl('L'),     alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 186, keyCap: ';:',         normal: DEFAULT,     ctrl: STRIP,        alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 222, keyCap: '\'"',        normal: DEFAULT,     ctrl: STRIP,        alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 13,  keyCap: '[Enter]',    normal: '\r',        ctrl: DEFAULT,      alt: DEFAULT,     meta: DEFAULT });

    // fifth row
    add({ keyCode: 16,  keyCap: '[Shift]', normal: PASS,        ctrl: PASS,                   alt: PASS,        meta: DEFAULT });
    add({ keyCode: 90,  keyCap: 'zZ',      normal: DEFAULT,     ctrl: ctl('Z'),               alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 88,  keyCap: 'xX',      normal: sl(DEFAULT), ctrl: sl(ctl('X')),           alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 67,  keyCap: 'cC',      normal: DEFAULT,     ctrl: ctl('C'),               alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 86,  keyCap: 'vV',      normal: DEFAULT,     ctrl: ctl('V'),               alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 66,  keyCap: 'bB',      normal: sl(DEFAULT), ctrl: sl(ctl('B')),           alt: sl(DEFAULT), meta: DEFAULT });
    add({ keyCode: 78,  keyCap: 'nN',      normal: DEFAULT,     ctrl: sl(ctl('N')),           alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 77,  keyCap: 'mM',      normal: DEFAULT,     ctrl: ctl('M'),               alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 188, keyCap: ',<',      normal: DEFAULT,     ctrl: alt(STRIP, PASS),       alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 190, keyCap: '.>',      normal: DEFAULT,     ctrl: alt(STRIP, PASS),       alt: DEFAULT,     meta: DEFAULT });
    add({ keyCode: 191, keyCap: '/?',      normal: DEFAULT,     ctrl: sh(ctl('_'), ctl('?')), alt: DEFAULT,     meta: DEFAULT });

    // sixth row
    add({ keyCode: 17, keyCap: '[Control]', normal: PASS,    ctrl: PASS,     alt: PASS,    meta: PASS });
    add({ keyCode: 18, keyCap: '[Alt]',     normal: PASS,    ctrl: PASS,     alt: PASS,    meta: PASS });
    add({ keyCode: 91, keyCap: '[Meta]',    normal: PASS,    ctrl: PASS,     alt: PASS,    meta: PASS });
    add({ keyCode: 32, keyCap: ' ',         normal: DEFAULT, ctrl: ctl('@'), alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 93, keyCap: '[Meta]',    normal: PASS,    ctrl: PASS,     alt: PASS,    meta: PASS });

    // these things.
    
    add({ keyCode: 42,  keyCap: '[PRTSCR]', normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });
    add({ keyCode: 145, keyCap: '[SCRLK]',  normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });
    add({ keyCode: 19,  keyCap: '[BREAK]',  normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });

    // block of six keys above the arrows
    add({ keyCode: 45, keyCap: '[Insert]',   normal: CSI + '2~', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 36, keyCap: '[Home]',     normal: ESC + 'OH', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 33, keyCap: '[PageUp]',   normal: CSI + '5~', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 46, keyCap: '[DEL]',      normal: CSI + '3~', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 35, keyCap: '[End]',      normal: ESC + 'OF', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 34, keyCap: '[PageDown]', normal: CSI + '6~', ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });

    // arrow keys
    add({ keyCode: 38, keyCap: '[ArrowUp]',    normal: sl(ac(CSI + 'A', SS3 + 'A')), ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 40, keyCap: '[ArrowDown]',  normal: sl(ac(CSI + 'B', SS3 + 'B')), ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 39, keyCap: '[ArrowRight]', normal: sl(ac(CSI + 'C', SS3 + 'C')), ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 37, keyCap: '[ArrowLeft]',  normal: sl(ac(CSI + 'D', SS3 + 'D')), ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });

    add({ keyCode: 144, keyCap: '[NUMLOCK]', normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });

    add({ keyCode: 12, keyCap: '[CLEAR]', normal: PASS, ctrl: PASS, alt: PASS, meta: PASS });

    // keypad with numlock
    add({ keyCode: 96,  keyCap: '[KP0]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 97,  keyCap: '[KP1]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 98,  keyCap: '[KP2]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 99,  keyCap: '[KP3]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 100, keyCap: '[KP4]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 101, keyCap: '[KP5]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 102, keyCap: '[KP6]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 103, keyCap: '[KP7]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 104, keyCap: '[KP8]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 105, keyCap: '[KP9]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 107, keyCap: '[KP+]', normal: DEFAULT, ctrl: onZoom,  alt: DEFAULT, meta: onZoom  });
    add({ keyCode: 109, keyCap: '[KP-]', normal: DEFAULT, ctrl: onZoom,  alt: DEFAULT, meta: onZoom  });
    add({ keyCode: 106, keyCap: '[KP*]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 111, keyCap: '[KP/]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });
    add({ keyCode: 110, keyCap: '[KP.]', normal: DEFAULT, ctrl: DEFAULT, alt: DEFAULT, meta: DEFAULT });

    this._reverseDefs['BracketLeft']  = this._defs[229];
    this._reverseDefs['BracketRight'] = this._defs[221];
    this._reverseDefs['Space']        = this._defs[32];
    this._reverseDefs['Backqoute']    = this._defs[192];
    this._reverseDefs['Slash']        = this._defs[191];
  }

  keyCode(ch: string): number {
    let def = this._reverseDefs[ch];
    if (def) {
      return def.keyCode;
    }
    return 0;
  }

  key(keyCode: number): string {
    let def = this._defs[keyCode];
    if (!def) {
      return '';
    }

    let nonPrintable = /^\[\w+\]$/.test(def.keyCap);
    if (nonPrintable) {
      return def.keyCap.replace(/[\[\]]/g, '');
    }
    return def.keyCap.substr(0, 1);
  }

  // prettier-ignore
  _onCtrlNum: KeyActionFunc = (e: KeyDownType, def: KeyDefType) => {
    switch (def.keyCap.substr(0, 1)) {
      case '1': return '1';
      case '2': return ctl('@');
      case '3': return ctl('[');
      case '4': return ctl('\\');
      case '5': return ctl(']');
      case '6': return ctl('^');
      case '7': return ctl('_');
      case '8': return DEL;
      case '9': return '9';
      default:  return PASS;
    }
  };

  _onAltNum: KeyActionFunc = (e: KeyDownType, def: KeyDefType) => DEFAULT;
  _onMetaNum: KeyActionFunc = (e: KeyDownType, def: KeyDefType) => DEFAULT;
  _onZoom: KeyActionFunc = (e: KeyDownType, def: KeyDefType) => {
    return CANCEL;
  };

  _onSel: KeyActionFunc = (e: KeyDownType, def: KeyDefType) => {
    if (def.keyCap == '[ArrowLeft]' || def.keyCap == 'hH') {
      let gran = e.shift ? 'word' : 'character';
      op('selection', {dir: 'left', gran});
    } else if (def.keyCap == '[ArrowRight]' || def.keyCap == 'lL') {
      let gran = e.shift ? 'word' : 'character';
      op('selection', {dir: 'right', gran});
    } else if (def.keyCap == '[ArrowUp]' || def.keyCap == 'kK') {
      op('selection', {dir: 'left', gran: 'line'});
    } else if (def.keyCap == '[ArrowDown]' || def.keyCap == 'jJ') {
      op('selection', {dir: 'right', gran: 'line'});
    } else if (def.keyCap == 'oO' || def.keyCap == 'xX') {
      op('selection', {command: 'change'});
    } else if (def.keyCap == 'nN' && e.ctrl) {
      op('selection', {dir: 'right', gran: 'line'});
    } else if (def.keyCap == 'pP') {
      if (e.ctrl) {
        op('selection', {dir: 'left', gran: 'line'});
      } else if (!e.shift && !e.alt && !e.meta) {
        op('selection', {command: 'paste'});
      }
    } else if (def.keyCap == 'bB') {
      if (e.ctrl) {
        op('selection', {dir: 'left', gran: 'character'});
      } else if (e.alt) {
        op('selection', {dir: 'left', gran: 'word'});
      } else {
        // ???
        op('selection', {dir: 'left', gran: 'word'});
      }
    } else if (def.keyCap == 'wW') {
      if (e.alt) {
        op('selection', {command: 'copy'});
      } else {
        op('selection', {dir: 'right', gran: 'word'});
      }
    } else if (def.keyCap == 'fF') {
      if (e.ctrl) {
        op('selection', {dir: 'right', gran: 'character'});
      } else if (e.alt) {
        op('selection', {dir: 'right', gran: 'word'});
      }
    } else if (def.keyCap == 'yY') {
      op('selection', {command: 'copy'});
    } else if (def.keyCap == '[Escape]') {
      op('selection', {command: 'cancel'});
    }
    return CANCEL;
  };
}
