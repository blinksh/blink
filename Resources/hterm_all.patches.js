'use strict';

// Blink: this function is copied from htrem_all.js. Search for `Blink:` for our modification
hterm.ScrollPort.prototype.decorate = function(div) {
  this.div_ = div;

  /* Blink: We don't need iframe. Lets use our document directly
  this.iframe_ = div.ownerDocument.createElement('iframe');
  this.iframe_.style.cssText =
  'border: 0;' + 'height: 100%;' + 'position: absolute;' + 'width: 100%';

   Set the iframe src to # in FF.  Otherwise when the frame's
   load event fires in FF it clears out the content of the iframe.
  if ('mozInnerScreenX' in window)
  // detect a FF only property
  this.iframe_.src = '#';

    div.appendChild(this.iframe_);
  */

  window.addEventListener('resize', this.onResize_.bind(this));

  var doc = (this.document_ = document);
  doc.body.style.cssText =
    'margin: 0px;' +
    'padding: 0px;' +
    'height: 100%;' +
    'width: 100%;' +
    'overflow: hidden;' +
    'cursor: var(--hterm-mouse-cursor-style);' +
    '-webkit-user-select: none;' +
    '-moz-user-select: none;';

  /* Blink: We already have this
    const metaCharset = doc.createElement('meta');
    metaCharset.setAttribute('charset', 'utf-8');
    doc.head.appendChild(metaCharset);
   */

  if (this.DEBUG_) {
    // When we're debugging we add padding to the body so that the offscreen
    // elements are visible.
    this.document_.body.style.paddingTop = this.document_.body.style.paddingBottom =
      'calc(var(--hterm-charsize-height) * 3)';
  }

  var style = doc.createElement('style');
  style.textContent =
    'x-row {' +
    '  display: block;' +
    '  height: var(--hterm-charsize-height);' +
    '  line-height: var(--hterm-charsize-height);' +
    '}';
  doc.head.appendChild(style);

  this.userCssLink_ = doc.createElement('link');
  this.userCssLink_.setAttribute('rel', 'stylesheet');

  this.userCssText_ = doc.createElement('style');
  doc.head.appendChild(this.userCssText_);

  // TODO(rginda): Sorry, this 'screen_' isn't the same thing as hterm.Screen
  // from screen.js.  I need to pick a better name for one of them to avoid
  // the collision.
  // We make this field editable even though we don't actually allow anything
  // to be edited here so that Chrome will do the right thing with virtual
  // keyboards and IMEs.  But make sure we turn off all the input helper logic
  // that doesn't make sense here, and might inadvertently mung or save input.
  // Some of these attributes are standard while others are browser specific,
  // but should be safely ignored by other browsers.
  this.screen_ = doc.createElement('x-screen');
  //  this.screen_.setAttribute('contenteditable', 'false'); // Blink: Set this to `false` makes selection on iOS possible.
  //  this.screen_.setAttribute('spellcheck', 'false');
  //  this.screen_.setAttribute('autocomplete', 'off');
  //  this.screen_.setAttribute('autocorrect', 'off');
  //  this.screen_.setAttribute('autocaptalize', 'none');
  //  this.screen_.setAttribute('role', 'textbox');
  this.screen_.setAttribute('tabindex', '-1');
  this.screen_.style.cssText =
    'caret-color: transparent;' +
    'display: block;' +
    'font-family: monospace;' +
    'font-size: 15px;' +
    //    'font-variant-ligatures: none;' + // Blink: We use ligatures a lot
    //     '-webkit-overflow-scrolling: touch;' +  // <-- for inertial scroll Blink: We love smooth scrolling
    'height: 100%;' +
    'overflow-y: scroll; overflow-x: hidden;' +
    'white-space: pre;' +
    'width: 100%;' +
    'outline: none !important';

  doc.body.appendChild(this.screen_);

  this.ime_ = doc.createElement('ime');
  this.screen_.appendChild(this.ime_);

  this.screen_.addEventListener('scroll', this.onScroll_.bind(this));
  this.screen_.addEventListener('wheel', this.onScrollWheel_.bind(this));
  /* Blink: We prefer native selection here
  this.screen_.addEventListener('touchstart', this.onTouch_.bind(this));
  this.screen_.addEventListener('touchmove', this.onTouch_.bind(this));
  this.screen_.addEventListener('touchend', this.onTouch_.bind(this));
  this.screen_.addEventListener('touchcancel', this.onTouch_.bind(this));
  */
  this.screen_.addEventListener('copy', this.onCopy_.bind(this));
  this.screen_.addEventListener('paste', this.onPaste_.bind(this));
  //  this.screen_.addEventListener('drop', this.onDragAndDrop_.bind(this));

  //  doc.body.addEventListener('keydown', this.onBodyKeyDown_.bind(this));

  // This is the main container for the fixed rows.
  this.rowNodes_ = doc.createElement('div');
  this.rowNodes_.id = 'hterm:row-nodes';
  this.rowNodes_.style.cssText =
    'display: block;' +
    //    'position: fixed;' +
    'position: absolute;' +
    'overflow: hidden;' +
    '-webkit-user-select: text;' +
    '-moz-user-select: text;';
  this.screen_.appendChild(this.rowNodes_);

  // Two nodes to hold offscreen text during the copy event.
  this.topSelectBag_ = doc.createElement('x-select-bag');
  this.topSelectBag_.style.cssText =
    'display: block;' +
    'overflow: hidden;' +
    'height: var(--hterm-charsize-height);' +
    'white-space: pre;';

  this.bottomSelectBag_ = this.topSelectBag_.cloneNode();

  // Nodes above the top fold and below the bottom fold are hidden.  They are
  // only used to hold rows that are part of the selection but are currently
  // scrolled off the top or bottom of the visible range.
  this.topFold_ = doc.createElement('x-fold');
  this.topFold_.id = 'hterm:top-fold-for-row-selection';
  this.topFold_.style.cssText = 'display: block;';
  this.rowNodes_.appendChild(this.topFold_);

  this.bottomFold_ = this.topFold_.cloneNode();
  this.bottomFold_.id = 'hterm:bottom-fold-for-row-selection';
  this.rowNodes_.appendChild(this.bottomFold_);

  // This hidden div accounts for the vertical space that would be consumed by
  // all the rows in the buffer if they were visible.  It's what causes the
  // scrollbar to appear on the 'x-screen', and it moves within the screen when
  // the scrollbar is moved.
  //
  // It is set 'visibility: hidden' to keep the browser from trying to include
  // it in the selection when a user 'drag selects' upwards (drag the mouse to
  // select and scroll at the same time).  Without this, the selection gets
  // out of whack.
  this.scrollArea_ = doc.createElement('div');
  this.scrollArea_.id = 'hterm:scrollarea';
  this.scrollArea_.style.cssText = 'visibility: hidden';
  this.screen_.appendChild(this.scrollArea_);

  // This svg element is used to detect when the browser is zoomed.  It must be
  // placed in the outermost document for currentScale to be correct.
  // TODO(rginda): This means that hterm nested in an iframe will not correctly
  // detect browser zoom level.  We should come up with a better solution.
  // Note: This must be http:// else Chrome cannot create the element correctly.
  var xmlns = 'http://www.w3.org/2000/svg';
  this.svg_ = this.div_.ownerDocument.createElementNS(xmlns, 'svg');
  this.svg_.id = 'hterm:zoom-detector';
  this.svg_.setAttribute('xmlns', xmlns);
  this.svg_.setAttribute('version', '1.1');
  this.svg_.style.cssText =
    'position: absolute;' + 'top: 0;' + 'left: 0;' + 'visibility: hidden';

  // We send focus to this element just before a paste happens, so we can
  // capture the pasted text and forward it on to someone who cares.
  this.pasteTarget_ = doc.createElement('textarea');
  this.pasteTarget_.id = 'hterm:ctrl-v-paste-target';
  this.pasteTarget_.setAttribute('tabindex', '-1');
  this.pasteTarget_.style.cssText =
    'position: absolute;' +
    'height: 1px;' +
    'width: 1px;' +
    'left: 0px; ' +
    'bottom: 0px;' +
    'opacity: 0';
  this.pasteTarget_.contentEditable = true;

  this.screen_.appendChild(this.pasteTarget_);
  this.pasteTarget_.addEventListener(
    'textInput',
    this.handlePasteTargetTextInput_.bind(this),
  );

  this.resize();
};

//hterm.Options = function(opt_copy) {
//  // All attributes in this class are public to allow easy access by the
//  // terminal.
//
//  this.wraparound = opt_copy ? opt_copy.wraparound : true;
//  this.reverseWraparound = opt_copy ? opt_copy.reverseWraparound : false;
//  this.originMode = opt_copy ? opt_copy.originMode : false;
//  // iOS terminal change: need autoCarriageReturn now that commands output info
//  // this.autoCarriageReturn = opt_copy ? opt_copy.autoCarriageReturn : false;
//  this.autoCarriageReturn = opt_copy ? opt_copy.autoCarriageReturn : true;
//  this.cursorVisible = opt_copy ? opt_copy.cursorVisible : false;
//  this.cursorBlink = opt_copy ? opt_copy.cursorBlink : false;
//  this.insertMode = opt_copy ? opt_copy.insertMode : false;
//  this.reverseVideo = opt_copy ? opt_copy.reverseVideo : false;
//  this.bracketedPaste = opt_copy ? opt_copy.bracketedPaste : false;
//};

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

hterm.Terminal.prototype.syncCursorPosition_ = function() {
  var topRowIndex = this.scrollPort_.getTopRowIndex();
  var bottomRowIndex = this.scrollPort_.getBottomRowIndex(topRowIndex);
  var cursorRowIndex =
    this.scrollbackRows_.length + this.screen_.cursorPosition.row;

  if (cursorRowIndex > bottomRowIndex) {
    // Cursor is scrolled off screen, move it outside of the visible area.
    this.setCssVar('cursor-offset-row', '-1');
    return;
  }

  if (this.options_.cursorVisible && this.cursorNode_.style.display == 'none') {
    // Re-display the terminal cursor if it was hidden by the mouse cursor.
    this.cursorNode_.style.display = '';
  }

  // Position the cursor using CSS variable math.  If we do the math in JS,
  // the float math will end up being more precise than the CSS which will
  // cause the cursor tracking to be off.
  /* BLINK: safari in iOS 10 doesn't support this syntax. We will do hybrid here
  this.setCssVar(
                 'cursor-offset-row',
                 `${cursorRowIndex - topRowIndex} + ` +
                 `${this.scrollPort_.visibleRowTopMargin}px`);
  */
  this.setCssVar(
    'cursor-offset-row',
    `${cursorRowIndex - topRowIndex + this.scrollPort_.visibleRowTopMargin}`,
  );

  this.setCssVar('cursor-offset-col', this.screen_.cursorPosition.column);

  this.cursorNode_.setAttribute(
    'title',
    '(' +
      this.screen_.cursorPosition.column +
      ', ' +
      this.screen_.cursorPosition.row +
      ')',
  );

  // Update the caret for a11y purposes.
  var selection = this.document_.getSelection();
  if (selection && selection.isCollapsed)
    this.screen_.syncSelectionCaret(selection);
};

// Optimizations

hterm.Screen.prototype.deleteChars = function(count) {
  var node = this.cursorNode_;
  var offset = this.cursorOffset_;

  //  var currentCursorColumn = this.cursorPosition.column;
  //  count = Math.min(count, this.columnCount_ - currentCursorColumn);
  //  if (!count) return 0;

  var rv = count;
  var startLength, endLength;

  while (node && count) {
    // Sanity check so we don't loop forever, but we don't also go quietly.
    if (count < 0) {
      console.error(`Deleting ${rv} chars went negative: ${count}`);
      break;
    }

    startLength = hterm.TextAttributes.nodeWidth(node);
    // Blink: optimization path for offset 0
    if (offset === 0) {
      if (count >= startLength) {
        node.textContent = '';
        endLength = 0;
      } else {
        setNodeText(node, hterm.TextAttributes.nodeSubstr(node, count));
        endLength = startLength - count;
      }
      // Blink: optimization path for offset >= startLength
    } else if (offset >= startLength) {
      endLength = startLength;
    } else {
      setNodeText(
        node,
        hterm.TextAttributes.nodeSubstr(node, 0, offset) +
          hterm.TextAttributes.nodeSubstr(node, offset + count),
      );
      endLength = hterm.TextAttributes.nodeWidth(node);
    }

    // Deal with splitting wide characters.  There are two ways: we could delete
    // the first column or the second column.  In both cases, we delete the wide
    // character and replace one of the columns with a space (since the other
    // was deleted).  If there are more chars to delete, the next loop will pick
    // up the slack.
    if (
      node.wcNode &&
      offset < startLength &&
      ((endLength && startLength == endLength) || (!endLength && offset == 1))
    ) {
      // No characters were deleted when there should be.  We're probably trying
      // to delete one column width from a wide character node.  We remove the
      // wide character node here and replace it with a single space.
      var spaceNode = this.textAttributes.createContainer(' ');
      node.parentNode.insertBefore(spaceNode, offset ? node : node.nextSibling);
      setNodeText(node, '');
      endLength = 0;
      count -= 1;
    } else count -= startLength - endLength;

    var nextNode = node.nextSibling;
    if (endLength == 0 && node != this.cursorNode_) {
      node.parentNode.removeChild(node);
    }
    node = nextNode;
    offset = 0;
  }

  // Remove this.cursorNode_ if it is an empty non-text node.
  if (
    this.cursorNode_.nodeType !== Node.TEXT_NODE &&
    !this.cursorNode_.textContent
  ) {
    var cursorNode = this.cursorNode_;
    if (cursorNode.previousSibling) {
      this.cursorNode_ = cursorNode.previousSibling;
      this.cursorOffset_ = hterm.TextAttributes.nodeWidth(
        cursorNode.previousSibling,
      );
    } else if (cursorNode.nextSibling) {
      this.cursorNode_ = cursorNode.nextSibling;
      this.cursorOffset_ = 0;
    } else {
      var emptyNode = this.cursorRowNode_.ownerDocument.createTextNode('');
      this.cursorRowNode_.appendChild(emptyNode);
      this.cursorNode_ = emptyNode;
      this.cursorOffset_ = 0;
    }
    this.cursorRowNode_.removeChild(cursorNode);
  }

  return rv;
};

hterm.Screen.prototype.overwriteString = function(str, wcwidth = undefined) {
  var maxLength = this.columnCount_ - this.cursorPosition.column;
  if (!maxLength) return [str];

  if (wcwidth === undefined) wcwidth = lib.wc.strWidth(str);

  if (
    this.textAttributes.matchesContainer(this.cursorNode_) &&
    this.cursorNode_.textContent.substr(this.cursorOffset_) == str
  ) {
    // This overwrite would be a no-op, just move the cursor and return.
    this.cursorOffset_ += wcwidth;
    this.cursorPosition.column += wcwidth;
    return;
  }

  // Blink optimization: Nothing to delete, just insert
  if (
    this.cursorOffset_ === 0 &&
    this.cursorPosition.column === 0 &&
    this.cursorRowNode_.textContent.length === 0
  ) {
    this.insertString(str, wcwidth);
  } else {
    // Blink optimization: if we insert first. It is more likly we will match text
    var node = this.cursorRowNode_;

    var parent = node.parentNode;
    var next = node.nextSibling;

    if (parent) {
      parent.removeChild(node);
    }

    this.insertString(str, wcwidth);
    this.deleteChars(wcwidth);

    if (parent) {
      parent[next ? 'insertBefore' : 'appendChild'](node, next);
    }
  }
};

hterm.TextAttributes.nodeWidth = function(node) {
  // 1. Try to use cached version. see hterm.setNodeText
  if (node._len !== undefined) {
    return node._len;
  }

  var content = node.textContent;
  // 2. If it asciiNode or text node use content length
  if (node.nodeType === Node.TEXT_NODE || node.asciiNode) {
    return content.length;
  }

  // 3. it is a row. Get width with nodeWidth in children
  if (node.nodeName === 'X-ROW') {
    var res = 0;
    var n = node.firstChild;
    while (n) {
      res += hterm.TextAttributes.nodeWidth(n);
      n = n.nextSibling;
    }
    return res;
  }

  // 4. We need to calculate wide char width
  return lib.wc.strWidth(content);
};

hterm.TextAttributes.nodeSubstr = function(node, start, width) {
  var content = node.textContent;

  if (node.nodeType === Node.TEXT_NODE || node.asciiNode) {
    return content.substr(start, width);
  }

  return lib.wc.substr(content, start, width);
};

hterm.Screen.prototype.splitNode_ = function(node, offset) {
  var afterNode = node.cloneNode(false);

  // Blink: Copy attributes back to afterNode
  afterNode.asciiNode = node.asciiNode;
  afterNode._len = node._len;
  if (node.wcNode) {
    afterNode.wcNode = node.wcNode;
  }

  var textContent = hterm.TextAttributes.nodeSubstr(node, 0, offset);
  var afterTextContent = hterm.TextAttributes.nodeSubstr(node, offset);

  if (afterTextContent) {
    setNodeText(afterNode, afterTextContent);
    node.parentNode.insertBefore(afterNode, node.nextSibling);
  }
  if (textContent) {
    setNodeText(node, textContent);
  } else {
    node.parentNode.removeChild(node);
  }
};

hterm.Terminal.prototype.scheduleSyncCursorPosition_ = function() {
  if (this.timeouts_.syncCursor) return;

  var self = this;
  this.timeouts_.syncCursor = requestAnimationFrame(function() {
    self.syncCursorPosition_();
    delete self.timeouts_.syncCursor;
  });
};

lib.wc.strWidth = function(str) {
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

//\u263A
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
