'use strict';

hterm.defaultStorage = new lib.Storage.Memory();

function _postMessage(op, data) {
  window.webkit.messageHandlers.interOp.postMessage({ op, data });
}

hterm.Terminal.prototype.copyStringToClipboard = function(str) {
  if (this.prefs_.get('enable-clipboard-notice')) {
    setTimeout(this.showOverlay.bind(this, hterm.notifyCopyMessage, 500), 200);
  }

  hterm.copySelectionToClipboard(this.document_, str);
};

hterm.copySelectionToClipboard = function(document, content) {
  var selection = document.getSelection();
  selection.removeAllRanges();
  _postMessage('copy', { content });
};

class Term {
  constructor() {
    this._size = { cols: 0, rows: 0 };
    this._hterm = new hterm.Terminal('blink');
    this._hterm.onTerminalReady = this._onTerminalReady.bind(this);

    // rebind directly to _hterm
    this.write = this._hterm.interpret.bind(this._hterm);
    this.clear = this._hterm.clear.bind(this._hterm);
    this.reset = this._hterm.reset.bind(this._hterm);

    this.focus = this._hterm.onFocusChange_.bind(this._hterm, true);
    this.blur = this._hterm.onFocusChange_.bind(this._hterm, false);
    
    this.init = this._hterm.decorate.bind(this._hterm);

    this._hterm.prefs_.set('audible-bell-sound', '');
    this._hterm.prefs_.set('receive-encoding', 'raw'); // we are UTF8
    this._hterm.prefs_.set('allow-images-inline', true); // need to make it work

    window.t = this._hterm; // For backward compatability
  }

  _onTerminalReady() {
    var screenSize = this._hterm.screenSize;

    this._size = { cols: screenSize.width, rows: screenSize.height };

    _postMessage('terminalReady', { size: this._size });

    this._hterm.io.onTerminalResize = (cols, rows) => {
      if (cols === this._size.cols && rows === this._size.rows) {
        return;
      }

      this._size = { cols, rows };

      _postMessage('sigwinch', this._size);
    };

    this._hterm.uninstallKeyboard();
  }

  increaseFontSize() {
    var size = this._hterm.getFontSize();
    this.setFontSize(++size);
  }

  decreaseFontSize() {
    var size = this._hterm.getFontSize();
    this.setFontSize(--size);
  }

  resetFontSize() {
    this.setFontSize(0);
  }

  scaleTermStart() {
    this._fontSize = this._hterm.getFontSize();
  }

  scaleTerm(scale) {
    var size = Math.min(Math.max(scale, 0.5), 2.0) * this._fontSize;
    this.setFontSize(Math.floor(size));
  }

  setFontSize(size) {
    this._hterm.prefs_.set('font-size', size);
    _postMessage('fontSizeChanged', { size: parseInt(size) });
  }

  setCursorBlink(state) {
    this._hterm.prefs_.set('cursor-blink', state);
  }

  setFontFamily(name) {
    this._hterm.prefs_.set('font-family', name + ', Menlo');
  }

  appendUserCSS(css) {
    var current = this._hterm.prefs_.get('user-css');
    if (!current) {
      current = 'data:text/css;utf-8,';
    }
    current += '\n' + css;
    this._hterm.prefs_.set('user-css', current);
  }

  loadFontFromCSS(cssPath, name) {
      WebFont.load({
        custom: {
          families: [name],
          urls: [cssPath],
        },
        active: () => this._hterm.syncFontFamily(),
      });
      this.setFontFamily(name);
  }
}
