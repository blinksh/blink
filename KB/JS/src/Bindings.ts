export type BindingAction =
  | {
      type: 'output',
      value: string,
      repeat: boolean,
    }
  | {
      type: 'state',
      state: string,
    }
  | {
      type: 'op',
      op: string,
      repeat: boolean,
    };

export default class Bindings {
  // TODO: match state later
  _stack: Array<string> = [];
  _map: {[index: string]: BindingAction} = {};

  match(keyIds: Array<string>): BindingAction | null {
    let keysPath = Array(keyIds)
      .sort()
      .join(':');
    let action = this._map[keysPath];
    return action;
  }
}
