'use strict';

hterm.defaultStorage = new lib.Storage.Memory();

function _postMessage(op, data) {
  window.webkit.messageHandlers.interOp.postMessage({ op, data });
}

hterm.copySelectionToClipboard = function(document, content) {
  document.getSelection().removeAllRanges();
  _postMessage('copy', { content });
};

hterm.ScrollPort.prototype.getTopRowIndex = function() {
  if (!this._scrollCache) {
    this._scrollCache = { top: this.screen_.scrollTop };
  }
  return Math.round(this._scrollCache.top / this.characterSize.height);
};

hterm.ScrollPort.prototype.onScroll_ = function(e) {
  this._scrollCache = null;
  var screenSize = this.getScreenSize();
  if (
    screenSize.width != this.lastScreenWidth_ ||
    screenSize.height != this.lastScreenHeight_
  ) {
    // This event may also fire during a resize (but before the resize event!).
    // This happens when the browser moves the scrollbar as part of the resize.
    // In these cases, we want to ignore the scroll event and let onResize
    // handle things.  If we don't, then we end up scrolling to the wrong
    // position after a resize.
    this.resize();
    return;
  }

  this.redraw_();
  this.publish('scroll', { scrollPort: this });
};

// Speedup a little bit.
hterm.Screen.prototype.syncSelectionCaret = function() {};

document.addEventListener('selectionchange', function() {
  _postMessage('selectionchange', term_getCurrentSelection());
});


hterm.Terminal.IO.prototype.sendString = function(string) {
  _postMessage('sendString', { string });
};

function _colorComponents(colorStr) {
  if (!colorStr) {
    return [0, 0, 0]; // Default is black
  }
  
  return colorStr.replace(/[^0-9,]/g, '').split(',').map(s => parseInt(s));
}

// Before we fully load hterm. We set options here.
var _prefs = new hterm.PreferenceManager('blink');
var t = { prefs_: _prefs }; // <- `t` will become actual hterm instance after decorate.

function term_set(key, value) {
  _prefs.set(key, value);
}

function term_get(key) {
  return _prefs.get(key);
}

function term_setupDefaults() {
  term_set('copy-on-select', false);
  term_set('audible-bell-sound', '');
  term_set('receive-encoding', 'raw'); // we are UTF8
//  term_set('allow-images-inline', true); // need to make it work
}

function term_setup() {
  t = new hterm.Terminal('blink');

  t.onTerminalReady = function() {
    t.io.onTerminalResize = function(cols, rows) {
      _postMessage('sigwinch', { cols, rows });
    };

    var size = {
      cols: t.screenSize.width,
      rows: t.screenSize.height,
    };
    document.body.style.backgroundColor = t.scrollPort_.screen_.style.backgroundColor;
    var bgColor = _colorComponents(t.scrollPort_.screen_.style.backgroundColor);
    _postMessage('terminalReady', { size, bgColor });

    t.uninstallKeyboard();
  };

  t.decorate(document.getElementById('terminal'));
}

function term_init() {
  term_setupDefaults();
  applyUserSettings();
  waitForFontFamily(term_setup);
}

function term_write(data) {
  t.interpret(data);
}

function term_clear() {
  t.clear();
}

function term_reset() {
  t.reset();
}

function term_focus() {
  t.onFocusChange__(true);
}

function term_blur() {
  t.onFocusChange__(false);
}

function term_setWidth(cols) {
  t.setWidth(cols);
}

function term_increaseFontSize() {
  var size = t.getFontSize();
  term_setFontSize((size + 1) + "px");
}

function term_decreaseFontSize() {
  var size = t.getFontSize();
  term_setFontSize((size - 1) + "px");
}

function term_resetFontSize() {
  term_setFontSize();
}

function term_scale(scale) {
  var minScale = 0.3;
  var maxScale = 3.0;
  scale = Math.max(minScale, Math.min(maxScale, scale));
  var fontSize = t.getFontSize();
  var newFontSize = Math.round(fontSize * scale);
  if (fontSize == newFontSize) {
    return;
  }
  term_setFontSize(newFontSize);
}

function term_setFontSize(size) {
  term_set('font-size', size);
  _postMessage('fontSizeChanged', { size: parseInt(size) });
}

function term_setCursorBlink(state) {
  term_set('cursor-blink', state);
}

function term_setFontFamily(name) {
  term_set('font-family', name + ', Menlo');
}

function term_appendUserCss(css) {
  var style = document.createElement('style');

  style.type = 'text/css';
  style.appendChild(document.createTextNode(css));

  document.head.appendChild(style);
}

function term_loadFontFromCss(url, name) {
  WebFont.load({
    custom: {
      families: [name],
      urls: [url],
    },
    active: function() {
      t.syncFontFamily();
    },
  });
  term_setFontFamily(name);
}

function term_getCurrentSelection() {
  const selection = document.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return { base: '', offset: 0, text: '' };
  }
  
  const r = selection.getRangeAt(0).getBoundingClientRect()

  const rect = ["{{", r.x, ",", r.y, "},{", r.width, ",", r.height, "}}"].join('');
  
  return {
    base: selection.baseNode.textContent,
    offset: selection.baseOffset,
    text: selection.toString(),
    rect
  };
}

function term_modifySelection(direction, granularity) {
  var selection = document.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return;
  }
  
  var fNode = selection.focusNode;
  var fOffset = selection.focusOffset;
  var aNode = selection.anchorNode;
  var aOffset = selection.anchorOffset;
  
  selection.modify("extend", direction, granularity);
  
  // we collapse selection, so swap direction and rerun modification again
  if (selection.isCollapsed) {
    selection.setBaseAndExtent(fNode, fOffset, aNode, aOffset);
    selection.modify("extend", direction, granularity);
  }
}

function term_modifySideSelection() {
  var selection = document.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return;
  }
  
  selection.setBaseAndExtent(selection.focusNode, selection.focusOffset, selection.anchorNode, selection.anchorOffset);
}

function term_cleanSelection() {
  document.getSelection().removeAllRanges();
}

function waitForFontFamily(callback) {
  const fontFamily = term_get('font-family');
  if (!fontFamily) {
    return callback();
  }

  const families = fontFamily.split(/\s*,\s*/);

  WebFont.load({
    custom: { families },
    active: callback,
    inactive: callback,
  });
}

function term_applySexyTheme(theme) {
  term_set('color-palette-overrides', theme.color);
  term_set('foreground-color', theme.foreground);
  term_set('background-color', theme.background);
}
