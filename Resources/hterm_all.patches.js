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

// NOTE(@nanzhong) hterm does not support DEC mode 1003 (any mouse event reporting mode).
// DEC mode 1003 and DEC mode 1002 (which hterm does support) are almost identical. The only difference is that mode 1003 includes mouse movement tracking events which are rarely used.
// This patches hterm to treat DEC mode 1003 the same as DEC mode 1002.

// DEC private mode 2026, synchronized output. Applications that repaint a full
// screen frequently (Claude Code, neovim, tmux) wrap each frame in
// CSI ? 2026 h ... CSI ? 2026 l so the terminal can present it atomically.
// Without it the screen is painted mid-frame and tears, which is very visible
// while a TUI streams. See blinksh/blink#1977.
//
// While a frame is open we swallow render requests and remember that something
// changed, then paint exactly once on close. A watchdog closes the frame if the
// end marker never arrives, so a misbehaving app cannot freeze the display.
var _blinkSyncOutput = {
  active: false,
  dirtyRows: false,
  needsRedraw: false,
  needsCursor: false,
  terminal: null,
  timer: null,
  WATCHDOG_MS: 150,

  begin: function(terminal) {
    this.terminal = terminal;
    _blinkWrapRenderRef(terminal && terminal.scrollPort_);
    this.active = true;

    var self = this;
    clearTimeout(this.timer);
    this.timer = setTimeout(function() { self.end(); }, this.WATCHDOG_MS);
  },

  end: function() {
    if (!this.active) {
      return;
    }
    this.active = false;
    clearTimeout(this.timer);
    this.timer = null;

    var terminal = this.terminal;
    var scrollPort = terminal && terminal.scrollPort_;
    if (!scrollPort) {
      return;
    }

    if (this.needsRedraw) {
      this.needsRedraw = false;
      hterm.ScrollPort.prototype.scheduleRedraw_original.call(scrollPort);
    }
    if (this.dirtyRows) {
      this.dirtyRows = false;
      var renderRef = scrollPort.renderRef;
      // A full touch re-renders every row, which subsumes the individual row
      // touches we swallowed while the frame was open.
      if (renderRef && renderRef._blinkTouchOriginal) {
        renderRef._blinkTouchOriginal();
      }
    }
    if (this.needsCursor) {
      this.needsCursor = false;
      hterm.Terminal.prototype.scheduleSyncCursorPosition__original.call(terminal);
    }
  },
};

// The React renderer is instantiated per ScrollPort, so it has to be wrapped on
// the instance rather than a prototype. Idempotent.
function _blinkWrapRenderRef(scrollPort) {
  var renderRef = scrollPort && scrollPort.renderRef;
  if (!renderRef || renderRef._blinkTouchOriginal) {
    return;
  }

  var touch = renderRef.touch.bind(renderRef);
  var touchRow = renderRef.touchRow.bind(renderRef);
  renderRef._blinkTouchOriginal = touch;

  // setRows() calls this.touch(), so assigning _rows still happens and only the
  // paint is deferred.
  renderRef.touch = function() {
    if (_blinkSyncOutput.active) {
      _blinkSyncOutput.dirtyRows = true;
      return;
    }
    touch();
  };

  renderRef.touchRow = function(row) {
    if (_blinkSyncOutput.active) {
      _blinkSyncOutput.dirtyRows = true;
      return;
    }
    touchRow(row);
  };
}

hterm.ScrollPort.prototype.scheduleRedraw_original =
  hterm.ScrollPort.prototype.scheduleRedraw;
hterm.ScrollPort.prototype.scheduleRedraw = function() {
  if (_blinkSyncOutput.active) {
    _blinkSyncOutput.needsRedraw = true;
    return;
  }
  hterm.ScrollPort.prototype.scheduleRedraw_original.call(this);
};

hterm.Terminal.prototype.scheduleSyncCursorPosition__original =
  hterm.Terminal.prototype.scheduleSyncCursorPosition_;
hterm.Terminal.prototype.scheduleSyncCursorPosition_ = function() {
  if (_blinkSyncOutput.active) {
    _blinkSyncOutput.needsCursor = true;
    return;
  }
  hterm.Terminal.prototype.scheduleSyncCursorPosition__original.call(this);
};

hterm.VT.prototype.setDECMode_original = hterm.VT.prototype.setDECMode;
hterm.VT.prototype.setDECMode = function(code, state) {
  if (code === "1003") {
    code = "1002";
  }

  if (String(code) === "2026") {
    if (state) {
      _blinkSyncOutput.begin(this.terminal);
    } else {
      _blinkSyncOutput.end();
    }
    return;
  }

  hterm.VT.prototype.setDECMode_original.call(this, code, state);
};
