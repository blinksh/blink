'use strict';

hterm.defaultStorage = new lib.Storage.Memory();

function _postMessage(op, data) {
  window.webkit.messageHandlers.interOp.postMessage({ op, data });
}

hterm.copySelectionToClipboard = function(document, content) {
  document.getSelection().removeAllRanges();
  _postMessage('copy', { content });
};


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


var term_write_b64 = null;

if (typeof TextDecoder !== 'undefined') {
  var _utf8TextDecoder = new TextDecoder('utf8');
  term_write_b64 = function term_write_b64_TextDecoder(b64str) {
    var bytes = base64js.toByteArray(b64str); // b64_to_uint8_array(b64str);
    var data = _utf8TextDecoder.decode(bytes);
    t.interpret(data);
  }
} else {
  // ios 10 support
  var _fileReader = new FileReader();
  var _blobOptions = {type: 'text/plain; charset=utf-8'};
  
  _fileReader.onload = function () {
    t.interpret(_fileReader.result);
  };
  
  term_write_b64 = function term_write_b64_blob(b64str) {
    var bytes = base64js.toByteArray(b64str); // b64_to_uint8_array(b64str);
    _fileReader.readAsText(new Blob([bytes], _blobOptions));
  }
}

function b64_to_uint8_array(b64Str) {
  var s = atob(b64Str);
  var len = s.length;
  var res = new Uint8Array(len);
  for (var i = 0; i < len; i++) {
    res[i] = s.charCodeAt(i);
  }
  return res;
}


function term_clear() {
  t.clear();
}

function term_setIme(str) {
  var length = lib.wc.strWidth(str);
  
  var scrollPort = t.scrollPort_;
  var ime = t.ime_;
  ime.textContent = str;
  
  if (length === 0) {
    return;
  }

  ime.style.backgroundColor = lib.colors.setAlpha(t.getCursorColor(), 1);
  ime.style.color = scrollPort.getBackgroundColor()
  
  var screenCols = t.screenSize.width;
  var cursorCol = t.screen_.cursorPosition.column;
  
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
  } else if (cursorCol + length <= screenCols ) {
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

function term_reportTouchInPoint(x, y) {
  var mousedown = new MouseEvent("mousedown", {});
  // One based row/column stored on the mouse event.
  mousedown.terminalRow = parseInt((y - t.scrollPort_.visibleRowTopMargin) /
                           t.scrollPort_.characterSize.height) + 1;
  mousedown.terminalColumn = parseInt(x /
                              t.scrollPort_.characterSize.width) + 1;
  t.onMouse(mousedown);
  var mouseup = new MouseEvent("mouseup", {});
  mouseup.terminalRow = mousedown.terminalRow;
  mouseup.terminalColumn = mousedown.terminalColumn;
  t.onMouse(mouseup);
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
  
  var dy = direction === 'left' ? -t.scrollPort_.characterSize.height : t.scrollPort_.characterSize.height;
  var dx = t.scrollPort_.characterSize.width;
  var range = selection.getRangeAt(0);
  
  var topLeft = true;
  if (fNode === aNode) {
    topLeft = fOffset < aOffset;
  } else {
    topLeft = range.compareNode(selection.focusNode) !== Range.NODE_AFTER;
  }
  
  if (topLeft) {
    // top left
    var rect = _filteredRects(range)[0];
    var point = { x: rect.left, y: rect.top + Math.abs(dy) * 0.5 };
    var newRange = document.caretRangeFromPoint(point.x, point.y + dy);
    if (!newRange) {
      selection.modify("extend", direction, 'line');
    } else {
      if (newRange.startContainer.textContent.length <= newRange.startOffset) {
        if (newRange.startContainer.nodeName === 'X-ROW' && newRange.startOffset === 0) {
          selection.setBaseAndExtent(aNode, aOffset, newRange.startContainer, newRange.startOffset);
          selection.modify("extend", 'left', 'character');
        } else {
          selection.setBaseAndExtent(aNode, aOffset, newRange.startContainer, Math.max(newRange.startOffset - 1, 0));
        }
      } else {
        selection.setBaseAndExtent(aNode, aOffset, newRange.startContainer, newRange.startOffset);
      }
    }
  } else {
    // bottom right
    var rects = _filteredRects(range);
    var rect = rects[rects.length - 1];
    var point = { x: rect.right, y: rect.bottom - Math.abs(dy) * 0.5};
    var newRange = document.caretRangeFromPoint(point.x, point.y + dy);
    if (newRange == null) {
      point.x -= dx * 0.5;
    }
    newRange = document.caretRangeFromPoint(point.x, point.y + dy);
    selection.setBaseAndExtent(aNode, aOffset, newRange.startContainer, newRange.startOffset);
  }
}

function _filteredRects(range) {
  var res = [];
  var rects = range.getClientRects();
  for (var i = 0; i < rects.length; i++) {
    var r = rects[i];
    if (r.width > 0) {
      res.push(r);
    }
  }
  return res;
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
  
  if (granularity === 'line') {
    _modifySelectionByLine(direction);
    if (selection.isCollapsed) {
      selection.setBaseAndExtent(fNode, fOffset, aNode, aOffset);
      _modifySelectionByLine(direction);
    }
    
    return;
  }
 
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
