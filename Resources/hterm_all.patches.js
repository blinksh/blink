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
  this.screen_.addEventListener('drop', this.onDragAndDrop_.bind(this));

  doc.body.addEventListener('keydown', this.onBodyKeyDown_.bind(this));

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

hterm.ScrollPort.prototype.focus = function() {
  //  this.iframe_.focus(); // Blink: No iframe anymore
  //this.screen_.focus();
};

hterm.Terminal.prototype.onFocusChange_ = function(focused) {
};

hterm.Terminal.prototype.onFocusChange__ = function(focused) {
  this.cursorNode_.setAttribute('focus', focused);
  this.restyleCursor_();
  
  if (this.reportFocus) {
    this.io.sendString(focused === true ? '\x1b[I' : '\x1b[O')
  }
  
  if (focused === true)
    this.closeBellNotifications_();
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
    if (this.timeouts_.cursorBlink)
      return;
    
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
