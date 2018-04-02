'use strict';

hterm.ScrollPort.prototype.focus = function() {
  //  this.iframe_.focus(); // Blink: No iframe anymore
  //this.screen_.focus();
};

hterm.Terminal.prototype.onFocusChange_ = function(focused) {};

hterm.Terminal.prototype.onFocusChange__ = function(focused) {
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

// https://medium.com/reactnative/emojis-in-javascript-f693d0eb79fb
const _emojiRegex = /(?:[\u2700-\u27bf]|(?:\ud83c[\udde6-\uddff]){2}|[\ud800-\udbff][\udc00-\udfff]|[\u0023-\u0039]\ufe0f?\u20e3|\u3299|\u3297|\u303d|\u3030|\u24c2|\ud83c[\udd70-\udd71]|\ud83c[\udd7e-\udd7f]|\ud83c\udd8e|\ud83c[\udd91-\udd9a]|\ud83c[\udde6-\uddff]|[\ud83c[\ude01-\ude02]|\ud83c\ude1a|\ud83c\ude2f|[\ud83c[\ude32-\ude3a]|[\ud83c[\ude50-\ude51]|\u203c|\u2049|[\u25aa-\u25ab]|\u25b6|\u25c0|[\u25fb-\u25fe]|\u00a9|\u00ae|\u2122|\u2139|\ud83c\udc04|[\u2600-\u26FF]|\u2b05|\u2b06|\u2b07|\u2b1b|\u2b1c|\u2b50|\u2b55|\u231a|\u231b|\u2328|\u23cf|[\u23e9-\u23f3]|[\u23f8-\u23fa]|\ud83c\udccf|\u2934|\u2935|[\u2190-\u21ff])/;

hterm.TextAttributes.prototype.createContainer = function(
  opt_textContent,
  opt_wcwidth,
) {
  if (this.isDefault()) {
    // Only attach attributes where we need an explicit default for the
    // matchContainer logic below.
    const node = this.document_.createTextNode(opt_textContent);
    //    node.asciiNode = true;
    //    if (opt_textContent != null) {
    //      node._len = opt_textContent.length;
    //    }
    return node;
  }

  var span = this.document_.createElement('span');
  var style = span.style;
  var classes = [];

  if (this.foreground != this.DEFAULT_COLOR) style.color = this.foreground;

  if (this.background != this.DEFAULT_COLOR)
    style.backgroundColor = this.background;

  if (this.enableBold && this.bold) style.fontWeight = 'bold';

  if (this.faint) span.faint = true;

  if (this.italic) style.fontStyle = 'italic';

  if (this.blink) {
    classes.push('blink-node');
    span.blinkNode = true;
  }

  let textDecorationLine = '';
  span.underline = this.underline;
  if (this.underline) {
    textDecorationLine += ' underline';
    style.textDecorationStyle = this.underline;
  }
  if (this.underlineSource != this.SRC_DEFAULT)
    style.textDecorationColor = this.underlineColor;
  if (this.strikethrough) {
    textDecorationLine += ' line-through';
    span.strikethrough = true;
  }
  if (textDecorationLine) style.textDecorationLine = textDecorationLine;

  if (this.wcNode) {
    classes.push('wc-node');
    span.wcNode = true;
    if (_emojiRegex.test(opt_textContent)) {
      classes.push('emoji');
    }
  }

  span.asciiNode = this.asciiNode;
                                                                                                                                                                                                                                                                                                                                                  
  if (this.tileData != null) {
    classes.push('tile');
    classes.push('tile_' + this.tileData);
    span.tileNode = true;
  }
                                                                                                                                                                                                                                                                                                                                                  
  if (opt_textContent) {
    setNodeText(span, opt_textContent, opt_wcwidth);
  }

  if (this.uri) {
    classes.push('uri-node');
    span.uriId = this.uriId;
    span.title = this.uri;
    span.addEventListener('click', hterm.openUrl.bind(this, this.uri));
  }

  if (classes.length) span.className = classes.join(' ');

  return span;
};
