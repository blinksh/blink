export type BindingAction =
  | {
      type: 'hex',
      value: string,
    }
  | {
      type: 'press',
      key: {
        keyCode: number,
        key: string,
        code: string,
        id: string,
      },
      shift: boolean,
      alt: boolean,
      ctrl: boolean,
      meta: boolean,
    }
  | {
      type: 'command',
      value: string,
    }
  | {
      type: 'none',
    };

export type KeyBinding = {
  keys: Array<string>,
  shiftLoc: number,
  controlLoc: number,
  optionLoc: number,
  commandLoc: number,
  action: BindingAction,
};

export default class Bindings {
  // TODO: match state later
  _stack: Array<string> = [];
  _map: {[index: string]: BindingAction} = {};

  reset() {
    this._stack = [];
    this._map = {};
  }

  match(keyIds: Array<string>): BindingAction | null {
    let keysPath = keyIds.sort().join(':');
    let action = this._map[keysPath];
    return action;
  }

  expandFn = (binding: KeyBinding) => {
    if (binding.keys.length == 0) {
      return;
    }
    let fns = [
      {
        keyCode: 121,
        key: 'F10',
        code: 'F10',
        id: '121:0',
      },
      {
        keyCode: 112,
        key: 'F1',
        code: 'F1',
        id: '112:0',
      },
      {
        keyCode: 113,
        key: 'F2',
        code: 'F2',
        id: '113:0',
      },
      {
        keyCode: 114,
        key: 'F3',
        code: 'F3',
        id: '114:0',
      },
      {
        keyCode: 115,
        key: 'F4',
        code: 'F4',
        id: '115:0',
      },
      {
        keyCode: 116,
        key: 'F5',
        code: 'F5',
        id: '116:0',
      },
      {
        keyCode: 117,
        key: 'F6',
        code: 'F6',
        id: '117:0',
      },
      {
        keyCode: 118,
        key: 'F7',
        code: 'F7',
        id: '118:0',
      },
      {
        keyCode: 119,
        key: 'F8',
        code: 'F8',
        id: '119:0',
      },
      {
        keyCode: 120,
        key: 'F9',
        code: 'F9',
        id: '120:0',
      },
    ];

    let keys = binding.keys.slice();
    for (var i = 0; i < 10; i++) {
      let numId = i + 48 + ':0';
      let fn = fns[i];
      binding.keys = keys.slice();
      binding.keys.push(numId);
      binding.action = {
        type: 'press',
        key: fn,
        alt: false,
        shift: false,
        ctrl: false,
        meta: false,
      };
      this._expandBinding(binding);
    }
  };

  expandCursor = (binding: KeyBinding) => {
    if (binding.keys.length == 0) {
      return;
    }
    let cursor = [
      {
        keyCode: 36,
        key: 'HOME',
        code: 'HOME',
        id: '36:0',
      },
      {
        keyCode: 33,
        key: 'PGUP',
        code: 'PGUP',
        id: '33:0',
      },
      {
        keyCode: 35,
        key: 'END',
        code: 'END',
        id: '35:0',
      },
      {
        keyCode: 34,
        key: 'PGDOWN',
        code: 'PGDOWN',
        id: '34:0',
      },
    ];
    let left = '37:0';
    let up = '38:0';
    let right = '39:0';
    let down = '40:0';
    let arrows = [left, up, right, down];
    let keys = binding.keys.slice();
    for (var i = 0; i < arrows.length; i++) {
      let arrow = arrows[i];
      let cur = cursor[i];
      binding.keys = keys.slice();
      binding.keys.push(arrow);
      binding.action = {
        type: 'press',
        key: cur,
        alt: false,
        shift: false,
        ctrl: false,
        meta: false,
      };
      this._expandBinding(binding);
    }
  };

  _expandBinding = (binding: KeyBinding) => {
    var keys = binding.keys.map(k => k.split('-')[0]);
    if (keys.length == 0) {
      return;
    }
    var res = [keys.sort()];
    var i = 0;

    const shift = {
      idLeft: '16:1',
      idRight: '16:2',
      loc: binding.shiftLoc,
    };
    const control = {
      idLeft: '17:1',
      idRight: '17:2',
      loc: binding.controlLoc,
    };
    const option = {
      idLeft: '18:1',
      idRight: '18:2',
      loc: binding.optionLoc,
    };
    const command = {
      idLeft: '91:1',
      idRight: '93:0',
      loc: binding.commandLoc,
    };

    var doubleKeys = [shift, control, option, command];

    for (let k of doubleKeys) {
      var i = res.length - 1;
      for (; i >= 0; i--) {
        var row = res[i];
        let idx = row.indexOf(k.idLeft);
        if (idx < 0) {
          idx = row.indexOf(k.idRight);
        }
        if (idx < 0) {
          continue;
        }
        if (k.loc == 1) {
          row[idx] = k.idLeft;
          continue;
        }
        if (k.loc == 2) {
          row[idx] = k.idRight;
          continue;
        }
        row[idx] = k.idLeft;
        let right = row.slice();
        right[idx] = k.idRight;
        res.push(right);
      }
    }

    for (let row of res) {
      let r = row.sort().join(':');
      this._map[r] = binding.action;
    }
  };
}
