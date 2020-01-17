import KeyMap, {
  CSI,
  DEL,
  ESC,
  IKeyboard,
  KBActions,
  KeyActionType,
  KeyDownType,
  KeyInfoType,
  op,
} from './KeyMap';
import {toUIKitFlags, UIKitFlagsToObject} from './UIKeyModifierFlags';
import Bindings, {BindingAction, KeyBinding} from './Bindings';

const CANCEL = KBActions.CANCEL;
const DEFAULT = KBActions.DEFAULT;
const PASS = KBActions.PASS;
const STRIP = KBActions.STRIP;

type KeyCode = {
  keyCode: number,
  key: string,
  code: string,
  id: string,
};

type KeyAction = '' | 'escape';

function hex_to_ascii(hex: string): string {
  let str = '';
  let len = hex.length;
  for (let n = 0; n < len; n += 2) {
    str += String.fromCharCode(parseInt(hex.substr(n, 2), 16));
  }
  return str;
}

function _action(action: KeyAction) {
  if (action !== 'escape') {
    return null;
  }

  return {
    keyCode: 27,
    code: '[Escape]',
    key: '[Escape]',
  };
}

type KeyModifier =
  | ''
  | 'Escape'
  | '8-bit'
  | 'Shift'
  | 'Control'
  | 'Meta'
  | 'Meta-Escape';

type KeyConfig = {
  code: KeyCode,
  up: KeyAction,
  down: KeyAction,
  mod: KeyModifier,
  ignoreAccents: boolean,
};

type KeyConfigPair = {
  left: KeyConfig,
  right: KeyConfig,
  bothAsLeft: boolean,
};

type KBConfig = {
  capsLock: KeyConfig,
  shift: KeyConfigPair,
  control: KeyConfigPair,
  option: KeyConfigPair,
  command: KeyConfigPair,
  fn: KeyBinding,
  cursor: KeyBinding,

  bindings: {[index: string]: BindingAction},
  shortcuts: Array<{action: BindingAction, input: string, modifiers: number}>,
};

const _holders = new Set([
  '20:0',
  '16:1',
  '16:2',
  '17:1',
  '17:2',
  '18:1',
  '18:2',
  '91:1',
  '91:2',
  '93:0',
]);

const _leftShift = '16:1';
const _leftControl = '17:1';
const _leftOption = '18:1';
const _leftCommand = '91:1';
const _capsLockID = '20:0';

// We track key by keyCode, code, location and key
function _keyId(e: KeyboardEvent): string {
  let keyCode = e.keyCode === 229 ? 0 : e.keyCode;
  let loc = e.location;
  if (keyCode) {
    // we can identitfy with pair keyCode and loc
    return `${keyCode}:${loc}`;
  }
  let key = (e.key || '').toLowerCase();
  return `${keyCode}:${loc}:${key}`;
}

function _removeAccents(str: string): string {
  let res = str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  let tmp = res.replace(/^[\u02c6\u00a8\u00b4\u02dc\u0060]/, '');
  if (tmp) {
    res = tmp;
  }
  return res;
}

function _blockEvent(e: UIEvent | null) {
  if (e) {
    e.preventDefault();
    e.stopPropagation();
  }
}

function _patchKeyDown(
  keyDown: KeyDownType,
  keyMap: KeyMap,
  e: KeyboardEvent | null,
): KeyDownType {
  if (!e) {
    return keyDown;
  }

  // iOS reports incorrect keyCode for h,i,c,m and [ with Control key pressed
  if (e.ctrlKey) {
    let ch = e.key.toLowerCase();
    let kc = e.keyCode;

    if (
      (kc === 8 && ch === 'h') ||
      (kc === 9 && ch === 'i') ||
      (kc === 13 && ch === 'c') ||
      (kc === 13 && ch === 'm') ||
      (kc === 27 && ch === '[')
    ) {
      keyDown.keyCode = keyMap.keyCode(ch) || keyDown.keyCode;
      return keyDown;
    }

    let c = e.code;
    if (
      (kc === 8 && c === 'KeyH') ||
      (kc === 9 && c === 'KeyI') ||
      (kc === 13 && c === 'KeyC') ||
      (kc === 13 && c === 'KeyM') ||
      (kc === 27 && c === 'BracketLeft')
    ) {
      keyDown.keyCode = keyMap.keyCode(c) || keyDown.keyCode;
    }
  }

  return keyDown;
}

export default class Keyboard implements IKeyboard {
  element = document.createElement('input');

  _keyMap = new KeyMap(this);
  _bindings = new Bindings();

  _lang: string = 'en';
  _langWithDeletes = false;
  _isHKB = false;

  hasSelection: boolean = false;

  _lastKeyDownEvent: KeyboardEvent | null = null;
  _capsLockRemapped = false;
  _shiftRemapped = false;
  _removeAccents = false;

  _metaSendsEscape: boolean = true;
  _altSendsWhat: 'escape' | '8-bit' = 'escape';

  _ignoreAccents = {
    AltLeft: true,
    AltRight: true,
  };

  _modsMap: {[index: string]: KeyModifier} = {
    ShiftLeft: 'Shift',
    ShiftRight: 'Shift',
    AltLeft: 'Escape',
    AltRight: 'Escape',
    MetaLeft: 'Meta',
    MetaRight: 'Meta',
    ControlLeft: 'Control',
    ControlRight: 'Control',
    CapsLock: '',
  };

  _downMap: {[index: string]: KeyInfoType} = {};
  _upMap: {[index: string]: KeyInfoType} = {};

  _mods: {[index: string]: Set<String>} = {
    Shift: new Set(),
    Alt: new Set(),
    Meta: new Set(),
    Control: new Set(),
  };

  _up: Set<string> = new Set();

  // custom shortcuts tracker
  _down: Set<string> = new Set();

  constructor() {
    let input = this.element;

    input.setAttribute('autocomplete', 'off');
    input.setAttribute('spellcheck', 'false');
    input.setAttribute('autocorrect', 'off');
    input.setAttribute('autocapitalize', 'none');
    input.setAttribute('autofocus', 'true');

    // keep one space, so delete always repeats on software kb
    input.value = ' ';

    input.addEventListener('keydown', this._onKeyDown);
    input.addEventListener('keyup', this._onKeyUp);

    window.addEventListener('keydown', this._onKeyDown);
    window.addEventListener('keyup', this._onKeyUp);

    // @ts-ignore
    input.addEventListener('compositionstart', this._onIME);
    // @ts-ignore
    input.addEventListener('compositionupdate', this._onIME);
    // @ts-ignore
    input.addEventListener('compositionend', this._onIME);

    // @ts-ignore
    input.addEventListener('beforeinput', this._onBeforeInput);
    // @ts-ignore
    input.addEventListener('input', this._onInput);

    this._updateRemappingFlags();
  }

  _updateRemappingFlags() {
    this._capsLockRemapped =
      this._modsMap['CapsLock'] != null ||
      this._downMap[_capsLockID] != null ||
      this._upMap[_capsLockID] != null;
    this._shiftRemapped =
      (this._modsMap['ShiftLeft'] != null &&
        this._modsMap['ShiftLeft'] !== 'Shift') ||
      (this._modsMap['ShiftRight'] != null &&
        this._modsMap['ShiftRight'] !== 'Shift');
  }

  _updateUIKitModsIfNeeded = (e: KeyboardEvent) => {
    let code = e.code;
    if (this._capsLockRemapped) {
      let mods: number;
      if (e.type == 'keyup' && code == 'CapsLock') {
        mods = 0;
      } else {
        mods = toUIKitFlags(e);
      }
      op('mods', {mods: mods});
    }

    if (code == 'AltLeft' || code == 'AltRight') {
      if (this._ignoreAccents[code]) {
        if (e.type == 'keydown') {
          op('guard-ime-on', {});
        } else {
          op('guard-ime-off', {});
        }
        _blockEvent(e);
      }
    }
  };

  _mod(mod: KeyModifier): 'Alt' | 'Meta' | 'Control' | 'Shift' | null {
    switch (mod) {
      case 'Escape':
        this._altSendsWhat = 'escape';
        return 'Alt';
      case '8-bit':
        this._altSendsWhat = '8-bit';
        return 'Alt';
      case 'Shift':
        return 'Shift';
      case 'Control':
        return 'Control';
      case 'Meta':
        this._metaSendsEscape = false;
        return 'Meta';
      case 'Meta-Escape':
        this._metaSendsEscape = true;
        return 'Meta';
      default:
        return null;
    }
  }

  _downKeysIds = () => {
    let res = Array.from(this._down);
    if (this._mods.Meta.has('tb-meta') && res.indexOf(_leftCommand) == -1) {
      res.push(_leftCommand);
    }
    if (this._mods.Control.has('tb-ctrl') && res.indexOf(_leftControl) == -1) {
      res.push(_leftControl);
    }
    if (this._mods.Alt.has('tb-alt') && res.indexOf(_leftOption) == -1) {
      res.push(_leftOption);
    }
    if (this._mods.Shift.has('tb-shift') && res.indexOf(_leftShift) == -1) {
      res.push(_leftShift);
    }
    return res;
  };

  _onKeyDown = (e: KeyboardEvent) => {
    if (e.isComposing) {
      this._lastKeyDownEvent = null;
      return;
    }
    let event: KeyboardEvent = e;
    // iOS sends 229 sometimes for repeated events
    if (e.keyCode === 229) {
      if (this._lastKeyDownEvent) {
        event = this._lastKeyDownEvent;
      } else {
        // dead
        return;
      }
    } else {
      this._lastKeyDownEvent = e;
    }

    let keyId = _keyId(event);
    this._down.add(keyId);

    let binding = this._bindings.match(this._downKeysIds());
    if (!_holders.has(keyId)) {
      this._down.delete(keyId);
    }
    if (binding) {
      this._execBinding(binding, e);
      _blockEvent(e);
      return;
    }

    let downOverride = this._downMap[keyId];
    let mod = this._mod(this._modsMap[event.code]);

    let handled = false;
    if (downOverride) {
      handled = !(mod && this._mods[mod].has(keyId));
      if (!handled) {
        this._handleKeyDownKey(downOverride, e);
        handled = true;
      }
    }
    if (mod) {
      this._mods[mod].add(keyId);
    }

    let upOverride = this._upMap[keyId];
    if (upOverride) {
      this._up.add(keyId);
    }

    this._updateUIKitModsIfNeeded(event);
    if (!handled) {
      this._handleKeyDown(event.keyCode, e);
    }
  };

  _onBeforeInput = (e: InputEvent) => {
    if (this._lang === 'dictation') {
      op('voice', {data: e.data || ''});
      return;
    }

    if (e.inputType === 'insertText') {
      this._output(e.data);
      if (this._langWithDeletes && e.data) {
        this.element.value = e.data;
        let len = e.data.length;
        this.element.selectionStart = len;
        this.element.selectionEnd = len;
      }
    }

    if (e.inputType === 'deleteContentBackward') {
      this._output(DEL);
    }

    _blockEvent(e);
  };

  // prevent simple input for IME mode (like 1, 2, 3 keys)
  _onInput = (e: InputEvent) => _blockEvent(e);

  _onKeyUp = (e: KeyboardEvent) => {
    this._lastKeyDownEvent = null;

    let keyId = _keyId(e);
    this._down.delete(keyId);
    let mod = this._mod(this._modsMap[e.code]);
    if (mod) {
      this._mods[mod].delete(keyId);
    }

    this._updateUIKitModsIfNeeded(e);

    let upOverride = this._upMap[keyId];
    if (upOverride && this._up.has(keyId)) {
      this._handleKeyDownKey(upOverride, null);
    }
    _blockEvent(e);
  };

  _handleKeyDown = (keyCode: number, e: KeyboardEvent | null) => {
    let keyInfo = {
      keyCode,
      key: '',
      code: 'Unidentified',
    };

    if (e) {
      keyInfo.code = e.code;
      keyInfo.key = e.key;
    }
    this._handleKeyDownKey(keyInfo, e);
  };

  _handleKeyDownKey = (keyInfo: KeyInfoType, e: KeyboardEvent | null) => {
    let keyMap = this._keyMap;

    let alt = this._mods.Alt.size > 0;
    let ctrl = this._mods.Control.size > 0;
    let meta = this._mods.Meta.size > 0;
    let shift = this._mods.Shift.size > 0;

    let code = keyInfo.code;
    let key = keyInfo.key;
    let keyCode = keyInfo.keyCode;

    let keyDown = _patchKeyDown(
      {key, code, keyCode, alt, ctrl, meta, shift},
      this._keyMap,
      e,
    );

    let keyDef = keyMap.getKeyDef(keyDown.keyCode);
    var resolvedActionType = null;

    function getAction(
      name: 'normal' | 'ctrl' | 'alt' | 'meta',
    ): KeyActionType {
      resolvedActionType = name;
      var action = keyDef[name];
      if (typeof action == 'function') {
        action = action.call(keyMap, keyDown, keyDef);
      }

      if (action === DEFAULT && name !== 'normal') {
        action = getAction('normal');
      }

      return action;
    }

    let action: KeyActionType;

    if (ctrl) {
      action = getAction('ctrl');
    } else if (alt) {
      action = getAction('alt');
    } else if (meta) {
      action = getAction('meta');
    } else {
      action = getAction('normal');
    }

    if (this._langWithDeletes && keyDef.keyCap === '[Backspace]') {
      return;
    }

    if (
      !this.hasSelection &&
      (action === PASS || (action === DEFAULT && !(ctrl || alt || meta)))
    ) {
      // If this key is supposed to be handled by the browser, or it is an
      // unmodified key with the default action, then exit this event handler.
      // If it's an unmodified key, it'll be handled in onKeyPress where we
      // can tell for sure which ASCII code to insert.
      //
      // This block needs to come before the STRIP test, otherwise we'll strip
      // the modifier and think it's ok to let the browser handle the keypress.
      // The browser won't know we're trying to ignore the modifiers and might
      // perform some default action.
      //  return;
      if (action === PASS && !keyInfo.src) {
        return;
      }

      let nonPrintable = /^\[\w+\]$/.test(keyDef.keyCap);

      if (nonPrintable) {
        if (!keyInfo.src) {
          this._removeAccents = false;
          return;
        }
      } else if (this._langWithDeletes) {
        // We pass to browser all printables
        return;
      }

      if (!this._isHKB) {
        // Some software KBs doesn't report shift presses (GBoard for instance)
        this._output(key);
        _blockEvent(e);
        return;
      }

      // TODO: may be remove accents only after options key is pressed.
      let out = this._removeAccents ? _removeAccents(key) : key;
      this._removeAccents = false;
      if (this._capsLockRemapped || this._shiftRemapped) {
        this._output(shift ? out.toUpperCase() : out.toLowerCase());
      } else {
        this._output(out);
      }

      _blockEvent(e);
      return;
    }
    this._removeAccents = false;

    if (action === STRIP) {
      alt = ctrl = false;
      action = keyDef.normal;
      if (typeof action == 'function') {
        action = action.call(keyMap, keyDown, keyDef);
      }

      if (action === DEFAULT && keyDef.keyCap.length === 2) {
        action = keyDef.keyCap.substr(shift ? 1 : 0, 1);
      }
    }

    _blockEvent(e);

    if (action === CANCEL || this.hasSelection) {
      return;
    }

    if (action !== DEFAULT && typeof action !== 'string') {
      console.log('Invalid action: ' + JSON.stringify(action));
      return;
    }

    // Strip the modifier that is associated with the action, since we assume that
    // modifier has already been accounted for in the action.
    if (resolvedActionType === 'ctrl') {
      ctrl = false;
    } else if (resolvedActionType === 'alt') {
      alt = false;
    } else if (resolvedActionType === 'meta') {
      meta = false;
    }

    shift = keyDown.shift;

    if (
      (alt || ctrl || shift || meta) &&
      typeof action === 'string' &&
      action.substr(0, 2) === CSI
    ) {
      // The action is an escape sequence that and it was triggered in the
      // presence of a keyboard modifier, we may need to alter the action to
      // include the modifier before sending it.

      // The math is funky but aligns w/xterm.
      let imod = 1;
      if (shift) imod += 1;
      if (alt) imod += 2;
      if (ctrl) imod += 4;
      if (meta) imod += 8;
      let mod = ';' + imod;

      if (action.length == 3) {
        // Some of the CSI sequences have zero parameters unless modified.
        action = CSI + '1' + mod + action.substr(2, 1);
      } else {
        // Others always have at least one parameter.
        action =
          action.substr(0, action.length - 1) +
          mod +
          action.substr(action.length - 1);
      }
    } else {
      if (action === DEFAULT) {
        action = keyDef.keyCap.substr(shift ? 1 : 0, 1);

        if (ctrl) {
          let unshifted = keyDef.keyCap.substr(0, 1);
          let code = unshifted.charCodeAt(0);
          if (code >= 64 && code <= 95) {
            action = String.fromCharCode(code - 64);
          }
        }
      }

      let actionStr = action.toString();

      if (alt && this._altSendsWhat == '8-bit' && actionStr.length == 1) {
        let code = actionStr.charCodeAt(0) + 128;
        action = String.fromCharCode(code);
      }

      // We respect alt/metaSendsEscape even if the keymap action was a literal
      // string.  Otherwise, every overridden alt/meta action would have to
      // check alt/metaSendsEscape.
      if (
        (alt && this._altSendsWhat == 'escape') ||
        (meta && this._metaSendsEscape)
      ) {
        action = ESC + actionStr;
      }
    }

    if (typeof action == 'string') {
      this._output(action);
    } else {
      console.warn('action is not a string', action);
    }
  };

  focus(value: boolean) {
    if (value) {
      this.element.focus();
    } else {
      this.element.blur();
    }
  }

  ready() {
    op('ready', {});
  }

  _onIME = (e: CompositionEvent) => {
    let type = e.type;
    let data = e.data || '';
    op('ime', {type, data});

    if (type == 'compositionend') {
      this._output(data);
    }
  };

  _handleCapsLockDown(down: boolean) {
    let mod = this._modsMap['CapsLock'];

    if (down) {
      this._down.add(_capsLockID);
      let override = this._downMap[_capsLockID];
      if (override && !(mod && this._mods[mod].has(_capsLockID))) {
        this._handleKeyDownKey(override, null);
      }
      if (mod) {
        this._mods[mod].add(_capsLockID);
      }
      let upOverride = this._upMap[_capsLockID];
      if (upOverride) {
        this._up.add(_capsLockID);
      }
      return;
    }
    this._down.delete(_capsLockID);
    mod && this._mods[mod].delete(_capsLockID);
    let upOverride = this._upMap[_capsLockID];
    if (upOverride && this._up.has(_capsLockID)) {
      this._handleKeyDownKey(upOverride, null);
    }
  }

  // Keyboard language change
  _handleLang(langAndKB: string) {
    let parts = langAndKB.split(':');
    this._lang = parts[0];
    this._isHKB = parts[1] === 'hw';

    this._langWithDeletes = this._lang === 'ko-KR';
    this._stateReset(this.hasSelection);
    if (this._lang !== 'dictation') {
      op('voice', {data: ''});
    }
  }

  _output = (data: string | null) => {
    this._up.clear();
    this.element.value = ' ';
    this.element.selectionStart = 1;
    this.element.selectionEnd = 1;
    if (data) {
      op('out', {data});
    }
  };

  _stateReset = (hasSelection: boolean) => {
    this._down.clear();
    this._up.clear();
    this._mods = {
      Shift: new Set(),
      Alt: new Set(),
      Meta: new Set(),
      Control: new Set(),
    };
    this.element.value = ' ';
    this.element.selectionStart = 1;
    this.element.selectionEnd = 1;
    this.hasSelection = hasSelection;
  };

  _handleGuard(up: boolean, char: string) {
    this.element.value = ' ';
    let keyCode = this._keyMap.keyCode(char);
    let keyId = `${keyCode}:0`;

    if (up) {
      this._down.delete(keyId);
      this._removeAccents = true;
      return;
    }

    this._down.add(keyId);
    this._handleKeyDown(keyCode, null);
  }

  _configKey = (key: KeyConfig) => {
    let code = key.code;
    let down = _action(key.down);
    if (down) {
      this._downMap[code.id] = down;
    }
    let mod = this._mod(key.mod);
    if (mod) {
      this._modsMap[code.code] = key.mod;
    }
    let up = _action(key.up);
    if (up) {
      this._upMap[code.id] = up;
    }

    if (code.code == 'AltRight' || code.code == 'AltLeft') {
      this._ignoreAccents[code.code] = key.ignoreAccents;
    }
  };

  _reset() {
    this.hasSelection = false;
    this._removeAccents = false;
    this._modsMap = {};
    this._downMap = {};
    this._upMap = {};
    this._up.clear();
    this._down.clear();
    this._mods = {
      Shift: new Set(),
      Alt: new Set(),
      Meta: new Set(),
      Control: new Set(),
    };
    this._ignoreAccents = {
      AltLeft: true,
      AltRight: true,
    };
  }

  _config = (cfg: KBConfig) => {
    this._reset();
    this._bindings.reset();

    this._configKey(cfg.capsLock);
    this._configKey(cfg.command.left);
    this._configKey(cfg.command.right);
    this._configKey(cfg.control.left);
    this._configKey(cfg.control.right);
    this._configKey(cfg.option.left);
    this._configKey(cfg.option.right);
    this._configKey(cfg.shift.left);
    this._configKey(cfg.shift.right);

    this._bindings.expandFn(cfg.fn);
    this._bindings.expandCursor(cfg.cursor);

    for (let shortcut of cfg.shortcuts) {
      let binding: KeyBinding = {
        keys: this._keysFromShortcut(shortcut.input, shortcut.modifiers),
        action: shortcut.action,
        shiftLoc: 0,
        controlLoc: 0,
        optionLoc: 0,
        commandLoc: 0,
      };
      this._bindings.expandBinding(binding);
    }

    this._updateRemappingFlags();
  };

  _keysFromShortcut(input: string, mods: number): Array<string> {
    var res: Array<string> = [];
    let m = UIKitFlagsToObject(mods);
    if (m.shift) {
      res.push(_leftShift);
    }
    if (m.alt) {
      res.push(_leftOption);
    }
    if (m.ctrl) {
      res.push(_leftControl);
    }
    if (m.meta) {
      res.push(_leftCommand);
    }
    let code = this._keyMap.keyCode(input);
    if (code) {
      res.push(code + ':0');
    } else {
      res.push('0:0-' + input);
    }
    return res;
  }

  _onToolbarMods = (val: number) => {
    let flags = UIKitFlagsToObject(val);
    if (flags.alt) {
      this._mods.Alt.add('tb-alt');
    } else {
      this._mods.Alt.delete('tb-alt');
    }

    if (flags.ctrl) {
      this._mods.Control.add('tb-ctrl');
    } else {
      this._mods.Control.delete('tb-ctrl');
    }

    if (flags.shift) {
      this._mods.Shift.add('tb-shift');
    } else {
      this._mods.Shift.delete('tb-shift');
    }

    if (flags.meta) {
      this._mods.Meta.add('tb-meta');
    } else {
      this._mods.Meta.delete('tb-meta');
    }
  };

  _execPress = (str: string, e: KeyboardEvent | null, skipBinding: boolean) => {
    let parts = str.split(/:/g);
    let savedMods = this._mods;
    this._mods = {
      Shift: new Set(),
      Alt: new Set(),
      Meta: new Set(),
      Control: new Set(),
    };
    let modFlags = parseInt(parts[0], 10);
    let mods = UIKitFlagsToObject(modFlags);
    if (mods.shift) {
      this._mods.Shift.add('tb-shift');
    }
    if (mods.ctrl) {
      this._mods.Control.add('tb-ctrl');
    }
    if (mods.alt) {
      this._mods.Alt.add('tb-alt');
    }
    if (mods.meta) {
      this._mods.Meta.add('tb-meta');
    }

    let keyCode = parseInt(parts[1], 10);
    let key =
      parts[3] == '' ? ':' : parts[3] || this._keyMap.key(keyCode) || '';

    let keyInfo: KeyInfoType = {
      keyCode,
      key,
      code: '',
      src: 'toolbar',
    };
    if (!skipBinding && modFlags > 0) {
      let keyId =
        keyInfo.keyCode + ':' + parts[2] + (keyCode == 0 ? ':' + key : '');
      this._down.add(keyId);
      let binding = this._bindings.match(this._downKeysIds());
      this._down.delete(keyId);
      if (binding) {
        this._execBinding(binding, null);
        this._mods = savedMods;
        return;
      }
    }
    this._handleKeyDownKey(keyInfo, e);
    this._mods = savedMods;
    this._removeAccents = true;
  };

  onKB = (cmd: string, arg: any) => {
    switch (cmd) {
      case 'mods-down':
        this._handleCapsLockDown(true);
        break;
      case 'mods-up':
        this._handleCapsLockDown(false);
        break;
      case 'guard-up':
        this._handleGuard(true, arg);
        break;
      case 'guard-down':
        this._handleGuard(false, arg);
        break;
      case 'selection':
        this.hasSelection = arg;
        break;
      case 'lang':
        this._handleLang(arg);
        break;
      case 'toolbar-mods':
        this._onToolbarMods(arg);
        break;
      case 'toolbar-press':
        this._execPress(arg, null, false);
        break;
      case 'press':
        this._execPress(arg, null, true);
        break;
      case 'state-reset':
        this._stateReset(arg);
        break;
      case 'focus':
        this.focus(arg);
        break;
      case 'hex':
        this._output(hex_to_ascii(arg));
        this._removeAccents = true;
        break;
      case 'config':
        this._config(arg);
        break;
    }
  };

  _execBinding(action: BindingAction, e: KeyboardEvent | null) {
    switch (action.type) {
      case 'command':
        op('command', {command: action.value});
        break;
      case 'press':
        this._execPress(`${action.mods}:${action.key.id}`, e, true);
        break;
      case 'hex':
        this._output(hex_to_ascii(action.value));
        this._removeAccents = true;
        break;
    }
  }
}
