hterm.defaultStorage = new lib.Storage.Memory();

hterm.ScrollPort.prototype.onTouch_ = function() {}; // disable build in touch support.

hterm.Terminal.prototype.copyStringToClipboard = function(str) {
  if (this.prefs_.get('enable-clipboard-notice'))
    setTimeout(this.showOverlay.bind(this, hterm.notifyCopyMessage, 500), 200);

  hterm.copySelectionToClipboard(this.document_, str);
};

hterm.copySelectionToClipboard = function(document, content) {
  var selection = document.getSelection();
  selection.removeAllRanges();
  window.webkit.messageHandlers.interOp.postMessage({
    op: 'copy',
    data: { content: content },
  });
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

    this.focus = this._hterm.focus.bind(this._hterm);
    this.blur = this._hterm.onFocusChange_.bind(this._hterm, false);

    this._hterm.prefs_.set(
      'user-css',
      'data:text/css;utf-8,* { font-feature-settings: "liga" 0; }',
    );
    this._hterm.prefs_.set('audible-bell-sound', '');
    this._hterm.prefs_.set('receive-encoding', 'raw'); // we are UTF8
    this._hterm.prefs_.set('allow-images-inline', true); // need to make it work

    window.t = this._hterm; // For backward compatability
  }

  init(element) {
    this._hterm.decorate(element);
  }

  _onTerminalReady() {
    var screenSize = this._hterm.screenSize;

    this._size = { cols: screenSize.width, rows: screenSize.height };

    window.webkit.messageHandlers.interOp.postMessage({
      op: 'terminalReady',
      data: { size: this._size },
    });

    this._hterm.io.onTerminalResize = (cols, rows) => {
      if (cols === this._size.cols || rows === this._size.rows) {
        return;
      }

      window.webkit.messageHandlers.interOp.postMessage({
        op: 'sigwinch',
        data: this._size,
      });
    };
    //this._hterm.keyboard.uninstallKeyboard();
  }

  sigwinch() {
    return;
    // This was removed as in theory the next resize would also take care of it.
    // It looks like under certain scenarios there is a race condition under which different sizes are
    // sent through different events on hterm and here included. This ensures that we take care of the
    // event chain ourselves.
    var screen = document
      .getElementsByTagName('iframe')[0]
      .contentWindow.document.getElementsByTagName('x-screen')[0];
    var view_w = window.innerWidth;
    var view_h = window.innerHeight;
    screen.style.width = view_w;
    screen.style.height = view_h;

    // This was done to fix the SplitView getting stuck.
    // It shouldn't be necessary anymore, but it makes transitions smoother too.
    var termWindow = document.getElementsByTagName('iframe')[0].contentWindow;
    termWindow.resizeTo(window.innerWidth, window.innerHeight);

    this._hterm.scrollPort_.onResize_(null);
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
    scale = Math.min(Math.max(scale, 0.5), 2.0);
    this.setFontSize(Math.floor(this._fontSize * scale));
  }

  setFontSize(size) {
    this._hterm.prefs_.set('font-size', size);
    //window.webkit.messageHandlers.interOp.postMessage({
    //op: 'fontSizeChanged',
    //data: { size: this._hterm.getFontSize() },
    //});
  }

  setCursorBlink(state) {
    this._hterm.prefs_.set('cursor-blink', state);
  }

  loadFontFromCSS(cssPath, name) {
    WebFont.load({
      custom: {
        families: [name],
        urls: [cssPath],
      },
      context: this._hterm.scrollPort_.iframe_.contentWindow,
      active: () => this._hterm.syncFontFamily(),
    });
    this._hterm.prefs_.set('font-family', name + ', Menlo');
  }
}
