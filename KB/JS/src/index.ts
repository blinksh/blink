import Keyboard from './Keyboard';

var keyboard = new Keyboard();

function install() {
  document.body.append(keyboard.element);
  keyboard.focus(true);
  window._onKB = keyboard.onKB;
  window._kb = keyboard;
  keyboard.ready();
}

install();


declare global {
    interface Window {
      _onKB: (cmd: string, arg: string) => any;
      _kb: Keyboard;
    }
}


