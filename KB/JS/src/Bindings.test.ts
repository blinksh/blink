import Bindings from './Bindings';
const shift = {
  idLeft: '16:1',
  idRight: '16:2',
};
const control = {
  idLeft: '17:1',
  idRight: '17:2',
};
const option = {
  idLeft: '18:1',
  idRight: '18:2',
};
const command = {
  idLeft: '91:1',
  idRight: '93:0',
};

test('_expandBinding empty', () => {
  let bindings = new Bindings();

  expect(bindings._map).toEqual({});

  bindings._expandBinding({
    keys: [],
    shiftLoc: 0,
    controlLoc: 0,
    optionLoc: 0,
    commandLoc: 0,
    action: {type: 'none'},
  });

  expect(bindings._map).toEqual({});
});

test('_expandBinding simple', () => {
  let bindings = new Bindings();

  bindings._expandBinding({
    keys: [shift.idLeft, 'r'],
    shiftLoc: 0,
    controlLoc: 0,
    optionLoc: 0,
    commandLoc: 0,
    action: {type: 'none'},
  });

  expect(bindings._map).toEqual({
    '16:1:r': {type: 'none'},
    '16:2:r': {type: 'none'},
  });
});

test('_expandBinding double', () => {
  let bindings = new Bindings();

  bindings._expandBinding({
    keys: [shift.idLeft, control.idLeft, 'r'],
    shiftLoc: 0,
    controlLoc: 0,
    optionLoc: 0,
    commandLoc: 0,
    action: {type: 'none'},
  });

  expect(bindings._map).toEqual({
    '16:1:17:1:r': {type: 'none'},
    '16:2:17:1:r': {type: 'none'},
    '16:1:17:2:r': {type: 'none'},
    '16:2:17:2:r': {type: 'none'},
  });
});

test('expandFN', () => {
  let bindings = new Bindings();
  bindings.expandFn({
    keys: [command.idLeft],
    shiftLoc: 0,
    controlLoc: 0,
    optionLoc: 0,
    commandLoc: 0,
    action: {type: 'none'},
  });

  expect(bindings._map).toEqual({
    '48:0:91:1': {
      type: 'press',
      key: {keyCode: 121, key: 'F10', code: 'F10', id: '121:0'},
      mods: 0,
    },
    '48:0:93:0': {
      type: 'press',
      key: {keyCode: 121, key: 'F10', code: 'F10', id: '121:0'},
      mods: 0,
    },
    '49:0:91:1': {
      type: 'press',
      key: {keyCode: 112, key: 'F1', code: 'F1', id: '112:0'},
      mods: 0,
    },
    '49:0:93:0': {
      type: 'press',
      key: {keyCode: 112, key: 'F1', code: 'F1', id: '112:0'},
      mods: 0,
    },
    '50:0:91:1': {
      type: 'press',
      key: {keyCode: 113, key: 'F2', code: 'F2', id: '113:0'},
      mods: 0,
    },
    '50:0:93:0': {
      type: 'press',
      key: {keyCode: 113, key: 'F2', code: 'F2', id: '113:0'},
      mods: 0,
    },
    '51:0:91:1': {
      type: 'press',
      key: {keyCode: 114, key: 'F3', code: 'F3', id: '114:0'},
      mods: 0,
    },
    '51:0:93:0': {
      type: 'press',
      key: {keyCode: 114, key: 'F3', code: 'F3', id: '114:0'},
      mods: 0,
    },
    '52:0:91:1': {
      type: 'press',
      key: {keyCode: 115, key: 'F4', code: 'F4', id: '115:0'},
      mods: 0,
    },
    '52:0:93:0': {
      type: 'press',
      key: {keyCode: 115, key: 'F4', code: 'F4', id: '115:0'},
      mods: 0,
    },
    '53:0:91:1': {
      type: 'press',
      key: {keyCode: 116, key: 'F5', code: 'F5', id: '116:0'},
      mods: 0,
    },
    '53:0:93:0': {
      type: 'press',
      key: {keyCode: 116, key: 'F5', code: 'F5', id: '116:0'},
      mods: 0,
    },
    '54:0:91:1': {
      type: 'press',
      key: {keyCode: 117, key: 'F6', code: 'F6', id: '117:0'},
      mods: 0,
    },
    '54:0:93:0': {
      type: 'press',
      key: {keyCode: 117, key: 'F6', code: 'F6', id: '117:0'},
      mods: 0,
    },
    '55:0:91:1': {
      type: 'press',
      key: {keyCode: 118, key: 'F7', code: 'F7', id: '118:0'},
      mods: 0,
    },
    '55:0:93:0': {
      type: 'press',
      key: {keyCode: 118, key: 'F7', code: 'F7', id: '118:0'},
      mods: 0,
    },
    '56:0:91:1': {
      type: 'press',
      key: {keyCode: 119, key: 'F8', code: 'F8', id: '119:0'},
      mods: 0,
    },
    '56:0:93:0': {
      type: 'press',
      key: {keyCode: 119, key: 'F8', code: 'F8', id: '119:0'},
      mods: 0,
    },
    '57:0:91:1': {
      type: 'press',
      key: {keyCode: 120, key: 'F9', code: 'F9', id: '120:0'},
      mods: 0,
    },
    '57:0:93:0': {
      type: 'press',
      key: {keyCode: 120, key: 'F9', code: 'F9', id: '120:0'},
      mods: 0,
    },
  });
});

test('expandCursor', () => {
  let bindings = new Bindings();
  bindings.expandCursor({
    keys: [shift.idLeft],
    shiftLoc: 0,
    controlLoc: 0,
    optionLoc: 0,
    commandLoc: 0,
    action: {type: 'none'},
  });

  expect(bindings._map).toEqual({
    '16:1:37:0': {
      type: 'press',
      key: {keyCode: 36, key: 'HOME', code: 'HOME', id: '36:0'},
      mods: 0,
    },
    '16:2:37:0': {
      type: 'press',
      key: {keyCode: 36, key: 'HOME', code: 'HOME', id: '36:0'},
      mods: 0,
    },
    '16:1:38:0': {
      type: 'press',
      key: {keyCode: 33, key: 'PGUP', code: 'PGUP', id: '33:0'},
      mods: 0,
    },
    '16:2:38:0': {
      type: 'press',
      key: {keyCode: 33, key: 'PGUP', code: 'PGUP', id: '33:0'},
      mods: 0,
    },
    '16:1:39:0': {
      type: 'press',
      key: {keyCode: 35, key: 'END', code: 'END', id: '35:0'},
      mods: 0,
    },
    '16:2:39:0': {
      type: 'press',
      key: {keyCode: 35, key: 'END', code: 'END', id: '35:0'},
      mods: 0,
    },
    '16:1:40:0': {
      type: 'press',
      key: {keyCode: 34, key: 'PGDOWN', code: 'PGDOWN', id: '34:0'},
      mods: 0,
    },
    '16:2:40:0': {
      type: 'press',
      key: {keyCode: 34, key: 'PGDOWN', code: 'PGDOWN', id: '34:0'},
      mods: 0,
    },
  });
});
