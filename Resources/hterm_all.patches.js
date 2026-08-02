'use strict';

hterm.Terminal.prototype.onFocusChange_ = function(focused) {};

hterm.Terminal.prototype.onFocusChange__ = function(focused) {
  var currentState = this.cursorNode_.getAttribute('focus');
  if (currentState === focused + '') {
    return;
  }

  this.cursorNode_.setAttribute('focus', focused);
  this.restyleCursor_();

  if (this.reportFocus) {
    this.io.sendString(focused === true ? '\x1b[I' : '\x1b[O');
  }

  if (focused === true) this.closeBellNotifications_();
};

// Do not show resize notifications. We show ours
hterm.Terminal.prototype.overlaySize = function() {};

hterm.Terminal.prototype.onMouse_ = function() {};

// TODO: Remove our patch. htermjs supports cursorBlinkPause_ option now
// see https://github.com/chromium/hterm/commit/f57d62de8f91f1fc8923fb000aeace041d063f9f
hterm.Terminal.prototype.setCursorVisible = function(state) {
  this.options_.cursorVisible = state;

  if (!state) {
    if (this.timeouts_.cursorBlink) {
      clearTimeout(this.timeouts_.cursorBlink);
      delete this.timeouts_.cursorBlink;
    }
    this.cursorNode_.style.opacity = '0';
    return;
  }

  this.syncCursorPosition_();

  this.cursorNode_.style.opacity = '1';

  if (this.options_.cursorBlink) {
    if (this.timeouts_.cursorBlink) return;

    // Blink: Switch the cursor off, so that the manual (first) blink trigger sets it on again
    this.cursorNode_.style.opacity = '0';
    this.onCursorBlink_();
  } else {
    if (this.timeouts_.cursorBlink) {
      clearTimeout(this.timeouts_.cursorBlink);
      delete this.timeouts_.cursorBlink;
    }
  }
};

// hterm's getSelectionText mixes DOM selection offsets (UTF-16 code units)
// with column widths. When a selection boundary falls inside a wide-char node
// (e.g. a single CJK character at end of line, where WebKit cannot normalize
// the boundary to the next text node), the wide char is cut in half and the
// extracted text comes back empty. Convert DOM offsets to columns first.
hterm.Terminal.prototype.getSelectionText = function() {
  var selection = this.scrollPort_.selection;
  selection.sync();

  if (selection.isCollapsed) return null;

  // Start offset measures from the beginning of the line.
  var startOffset = selection.startOffset;
  var node = selection.startNode;

  // If an x-row isn't selected, |node| will be null.
  if (!node) return null;

  if (node.nodeName != 'X-ROW') {
    // If the selection doesn't start on an x-row node, then it must be
    // somewhere inside the x-row.  Add any characters from previous siblings
    // into the start offset.

    if (node.nodeName == '#text') {
      startOffset = lib.wc.strWidth(
        node.textContent.substring(0, selection.startOffset));

      if (node.parentNode.nodeName == 'SPAN') {
        // If node is the text node in a styled span, move up to the span node.
        node = node.parentNode;
      }
    }

    while (node.previousSibling) {
      node = node.previousSibling;
      startOffset += hterm.TextAttributes.nodeWidth(node);
    }
  }

  // End offset measures from the end of the line.
  var endOffset =
    hterm.TextAttributes.nodeWidth(selection.endNode) - selection.endOffset;
  node = selection.endNode;

  if (node.nodeName != 'X-ROW') {
    // If the selection doesn't end on an x-row node, then it must be
    // somewhere inside the x-row.  Add any characters from following siblings
    // into the end offset.

    if (node.nodeName == '#text') {
      endOffset = hterm.TextAttributes.nodeWidth(node) -
        lib.wc.strWidth(node.textContent.substring(0, selection.endOffset));

      if (node.parentNode.nodeName == 'SPAN') {
        // If node is the text node in a styled span, move up to the span node.
        node = node.parentNode;
      }
    }

    while (node.nextSibling) {
      node = node.nextSibling;
      endOffset += hterm.TextAttributes.nodeWidth(node);
    }
  }

  var rv = this.getRowsText(
    selection.startRow.rowIndex,
    selection.endRow.rowIndex + 1
  );
  return lib.wc.substring(rv, startOffset, lib.wc.strWidth(rv) - endOffset);
};

// NOTE(@nanzhong) hterm does not support DEC mode 1003 (any mouse event reporting mode).
// DEC mode 1003 and DEC mode 1002 (which hterm does support) are almost identical. The only difference is that mode 1003 includes mouse movement tracking events which are rarely used.
// This patches hterm to treat DEC mode 1003 the same as DEC mode 1002.

hterm.VT.prototype.setDECMode_original = hterm.VT.prototype.setDECMode;
hterm.VT.prototype.setDECMode = function(code, state) {
  if (code === "1003") {
    code = "1002";
  }
  hterm.VT.prototype.setDECMode_original.call(this, code, state);
};

// Normalize before changing alpha.
// Upstream has fixed other paths like b7e97ea1, but it won't hit this one
// when injeting themes, which is why we are patching here.
(function() {
  var originalSetAlpha = lib.colors.setAlpha;
  lib.colors.setAlpha = function(color, alpha) {
    if (typeof color === 'string') {
      const normalized = lib.colors.normalizeCSS(color);
      if (!normalized) return color; // Unnormalizable - drop alpha
      color = normalized;
    }
    return originalSetAlpha.call(this, color, alpha);
  };
})();
