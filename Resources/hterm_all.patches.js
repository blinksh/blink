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

hterm.Terminal.prototype.copyStringToClipboard = function(str) {
  if (this.prefs_.get('enable-clipboard-notice')) {
    setTimeout(this.showOverlay.bind(this, hterm.notifyCopyMessage, 500), 200);
  }

  hterm.copySelectionToClipboard(this.document_, str);
};

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

var _asciiOnlyRegex = /^[\x00-\x7F]*$/;

hterm.TextAttributes.splitWidecharString = function(str) {
  if (_asciiOnlyRegex.test(str)) {
    return [
      { str: str,
        wcNode: false,
        asciiNode: true,
        wcStrWidth: str.length
      }
    ];
  }
  
  var rv = [];
  var base = 0, length = 0, wcStrWidth = 0, wcCharWidth;
  var asciiNode = true;
  
  var len = str.length;
  for (var i = 0; i < len;) {
    var c = str.codePointAt(i);
    var increment;
    if (c < 128) {
      wcStrWidth += 1;
      length += 1;
      increment = 1;
    } else {
      increment = (c <= 0xffff) ? 1 : 2;
      wcCharWidth = lib.wc.charWidth(c);
      if (wcCharWidth <= 1) {
        wcStrWidth += wcCharWidth;
        length += increment;
        asciiNode = false;
      } else {
        if (length) {
          rv.push({
                  str: str.substr(base, length),
                  wcNode: false,
                  asciiNode: asciiNode,
                  wcStrWidth: wcStrWidth,
                  });
          asciiNode = true;
          wcStrWidth = 0;
        }
        rv.push({
                str: str.substr(i, increment),
                wcNode: true,
                asciiNode: false,
                wcStrWidth: 2,
                });
        base = i + increment;
        length = 0;
      }
    }
    i += increment;
  }
  
  if (length) {
    rv.push({
            str: str.substr(base, length),
            wcNode: false,
            asciiNode: asciiNode,
            wcStrWidth: wcStrWidth,
            });
  }
  
  return rv;
};

lib.wc.substr = function(str, start, opt_width) {
  if (_asciiOnlyRegex.test(str)) {
    return str.substr(start, opt_width);
  }
  
  var startIndex = 0;
  var endIndex, width;
  
  // Fun edge case: Normally we associate zero width codepoints (like combining
  // characters) with the previous codepoint, so we skip any leading ones while
  // including trailing ones.  However, if there are zero width codepoints at
  // the start of the string, and the substring starts at 0, lets include them
  // in the result.  This also makes for a simple optimization for a common
  // request.
  if (start) {
    for (width = 0; startIndex < str.length;) {
      const codePoint = str.codePointAt(startIndex);
      width += lib.wc.charWidth(codePoint);
      if (width > start)
        break;
      startIndex += (codePoint <= 0xffff) ? 1 : 2;
    }
  }
  
  if (opt_width != undefined) {
    for (endIndex = startIndex, width = 0; endIndex < str.length;) {
      const codePoint = str.codePointAt(endIndex);
      width += lib.wc.charWidth(codePoint);
      if (width > opt_width)
        break;
      endIndex += (codePoint <= 0xffff) ? 1 : 2;
    }
    return str.substring(startIndex, endIndex);
  }
  
  return str.substr(startIndex);
};


lib.wc.strWidth = function(str) {
  if (_asciiOnlyRegex.test(str)) {
    return str.length;
  }
  
  var width,
    rv = 0;

  for (var i = 0, len = str.length; i < len; ) {
    var codePoint = str.codePointAt(i);
    width = lib.wc.charWidth(codePoint);
    if (width < 0) return -1;
    rv += width;
    i += codePoint <= 0xffff ? 1 : 2;
  }

  return rv;
};

