'use strict';

hterm.defaultStorage = new lib.Storage.Memory();

function _postMessage(op, data) {
  window.webkit.messageHandlers.interOp.postMessage({ op, data });
}

hterm.copySelectionToClipboard = function(document, content) {
  document.getSelection().removeAllRanges();
  _postMessage('copy', { content });
};

var _scrollCache = null;

hterm.ScrollPort.prototype.getTopRowIndex = function() {
  if (!_scrollCache) {
    _scrollCache = { top: this.screen_.scrollTop };
  }
  return Math.round(_scrollCache.top / this.characterSize.height);
};

hterm.ScrollPort.prototype.onScroll_ = function(e) {
  _scrollCache = null;
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
//hterm.Screen.prototype._insertString = hterm.Screen.prototype.insertString;
//
//hterm.Screen.prototype.insertString = function(str, wcwidth = undefined) {
//  this._insertString(str, wcwidth);
//  _scrollCache = null; // we need safari to reflow...
//};

// Speedup a little bit.
hterm.Screen.prototype.syncSelectionCaret = function() {};

document.addEventListener('selectionchange', function() {
  _postMessage('selectionchange', term_getCurrentSelection());
});


hterm.Terminal.IO.prototype.sendString = function(string) {
  _postMessage('sendString', { string });
};

hterm.msg = function() {}; // TODO: show messages

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
  term_set('allow-images-inline', true); // need to make it work
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

function term_setIme(str) {
  
  var length = lib.wc.strWidth(str);
  
  var scrollPort = t.scrollPort_;
  var ime = scrollPort.ime_;
  ime.textContent = str;
  
  if (length === 0) {
    return;
  }

  ime.style.backgroundColor = lib.colors.setAlpha(t.getCursorColor(), 1);
  ime.style.color = scrollPort.getBackgroundColor()
  
  var screenCols = t.screenSize.width;
  var cursorCol = t.screen_.cursorPosition.column + t.screen_.cursorOffset_;
  
  ime.style.bottom = 'auto';
  ime.style.top = 'auto';
  
  if (length >= screenCols) {
    // We are wider than the screen
    ime.style.left = '0px';
    ime.style.right = '0px';
    if (t.screen_.cursorPosition.row < t.screenSize.height * 0.8) {
      ime.style.top = 'calc(var(--hterm-charsize-height) * (var(--hterm-cursor-offset-row) + 1))'
    } else {
      ime.style.top = 'calc(var(--hterm-charsize-height) * (var(--hterm-cursor-offset-row) - ' + (Math.floor(length / (screenCols + 1))) + ' - 1))'
    }
  } else if ((cursorCol + length - 2) <= screenCols ) {
    // we are inlined
    ime.style.left = 'calc(var(--hterm-charsize-width) * var(--hterm-cursor-offset-col))';
    ime.style.top = 'calc(var(--hterm-charsize-height) * var(--hterm-cursor-offset-row))';
    ime.style.right = 'auto';
  } else if (t.screen_.cursorPosition.row == 0) {
    // we are at the end of line but need more space at the bottom
    ime.style.top = 'calc(var(--hterm-charsize-height) * (var(--hterm-cursor-offset-row) + 1))';
    ime.style.left = 'auto';
    ime.style.right = '0px';
  } else {
    // we are at the end of line but need more space at the top
    ime.style.top = 'calc(var(--hterm-charsize-height) * (var(--hterm-cursor-offset-row) - 1))';
    ime.style.left = 'auto';
    ime.style.right = '0px';
  }
  var r = ime.getBoundingClientRect()
  
  const markedRect = ["{{", r.x, ",", r.y, "},{", r.width, ",", r.height, "}}"].join('');
  
  return {markedRect};
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

function _modifySelectionByLine(direction) {
  var selection = document.getSelection();
  var fNode = selection.focusNode;
  var fOffset = selection.focusOffset;
  var aNode = selection.anchorNode;
  var aOffset = selection.anchorOffset;
  
  var fRow = t.screen_.getXRowAncestor_(fNode);
  
  var targetRow = direction === 'left' ?  fRow.previousSibling : fRow.nextSibling;
  
  // We out of screen
  if (targetRow == null || targetRow.nodeName !== 'X-ROW') {
    if (direction === 'left') {
      selection.setBaseAndExtent(aNode, aOffset, fRow, 0);
    } else {
      selection.setBaseAndExtent(aNode, aOffset, fRow.nextSibling, 0);
    }
    
    return;
  }
  
  if (fNode.nodeName === 'X-ROW') {
    if (direction === 'left') {
      selection.setBaseAndExtent(aNode, aOffset, fNode.previousSibling, 0);
      selection.modify("extend", direction, 'character');
    } else {
      selection.setBaseAndExtent(aNode, aOffset, fNode.nextSibling, 0);
    }
    
    return;
  }
  
  var position = t.screen_.getPositionWithinRow_(fRow, fNode, fOffset);
  var nodeAndOffset = t.screen_.getNodeAndOffsetWithinRow_(targetRow, position);
  
  if (nodeAndOffset) {
    selection.setBaseAndExtent(aNode, aOffset, nodeAndOffset[0], nodeAndOffset[1]);
    
    if (selection.isCollapsed) {
      selection.setBaseAndExtent(fNode, fOffset, aNode, aOffset);
      _modifySelectionByLine(direction);
    }
    return;
  }
  
  if (direction === 'left') {
    selection.setBaseAndExtent(aNode, aOffset, fRow, 0);
    selection.modify("extend", direction, 'character');
  } else {
    selection.setBaseAndExtent(aNode, aOffset, targetRow, 0);
    selection.modify("extend", direction, 'lineboundary');
    selection.modify("extend", direction, 'character');
  }
}

function term_modifySelection(direction, granularity) {
  var selection = document.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return;
  }
  
  if (granularity === 'line') {
    _modifySelectionByLine(direction);
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

function term_setAutoCarriageReturn(state) {
  t.setAutoCarriageReturn(state);
}
