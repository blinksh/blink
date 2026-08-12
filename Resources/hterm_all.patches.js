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

hterm.VT.prototype.setDECMode_original = hterm.VT.prototype.setDECMode;
hterm.VT.prototype.setDECMode = function(code, state) {
  if (code === "1003") {
    code = "1002";
  }
  hterm.VT.prototype.setDECMode_original.call(this, code, state);
};

// Fix #2232: iOS WebKit draws characters that are Emoji=Yes but
// Emoji_Presentation=No (U+23FA, U+23F8, U+2764, ...) with the colour emoji
// font, so they advance about two cells while charWidth() reports 1. The row
// then runs wider than the grid and later cells drift, which reads as clipping
// and flicker while a full screen TUI repaints.
//
// CSS cannot fix it, since iOS WebKit does not implement font-variant-emoji.
// Appending VS15 (U+FE0E) restores text presentation, and VS15 is zero width
// in hterm's combining table, so column accounting is unchanged.
//
// The affected codepoints vary by iOS version and font, so measure the glyph
// once and memoise rather than ship a Unicode table that goes stale.

var _blinkTextPresentation = {
  VS15: '︎',
  cache: new Map(),
  el: null,
  font: null,
  refWidth: 0,

  // A hidden span that inherits the terminal's current font, so measurements
  // reflect what the screen is actually rendering with.
  measurer: function() {
    var screen = document.querySelector('x-screen');
    var font = screen ? getComputedStyle(screen).font : '';

    if (this.el && this.font === font) {
      return this.el;
    }

    if (!this.el) {
      this.el = document.createElement('span');
      this.el.style.cssText =
        'position:absolute;top:-9999px;left:-9999px;visibility:hidden;' +
        'white-space:pre;padding:0;margin:0;border:0;';
      document.body.appendChild(this.el);
    }

    // Font changed (or first use): re-measure the reference cell and drop the
    // memoised answers, which were keyed to the old font.
    this.el.style.font = font;
    this.font = font;
    this.cache.clear();
    this.el.textContent = 'M';
    this.refWidth = this.el.getBoundingClientRect().width;

    return this.el;
  },

  // True when WebKit draws this codepoint wider than the single cell hterm
  // reserved for it.
  needsTextSelector: function(codePoint) {
    var cached = this.cache.get(codePoint);
    if (cached !== undefined) {
      return cached;
    }

    // Wider characters get their own wc-node with an explicit width, so they
    // are already accounted for and must be left alone.
    if (lib.wc.charWidth(codePoint) !== 1) {
      this.cache.set(codePoint, false);
      return false;
    }

    var el = this.measurer();
    if (!this.refWidth) {
      return false;
    }

    el.textContent = String.fromCodePoint(codePoint);
    var ratio = el.getBoundingClientRect().width / this.refWidth;

    // Emoji glyphs come out near 2.0, text glyphs sit around 1.0. Anything
    // past the midpoint is overflowing its cell.
    var needs = ratio > 1.4;
    this.cache.set(codePoint, needs);
    return needs;
  },
};

function _blinkForceTextPresentation(str) {
  // Fast path: pure Latin-1 can never hit this, which covers almost all output.
  if (!/[^\x00-\xFF]/.test(str)) {
    return str;
  }

  var chars = Array.from(str);
  var out = '';
  var changed = false;

  for (var i = 0; i < chars.length; i++) {
    var ch = chars[i];
    var cp = ch.codePointAt(0);
    out += ch;

    if (cp <= 0xFF) {
      continue;
    }

    // Respect an explicit presentation choice already in the stream.
    var next = chars[i + 1] ? chars[i + 1].codePointAt(0) : 0;
    if (next >= 0xFE00 && next <= 0xFE0F) {
      continue;
    }

    if (_blinkTextPresentation.needsTextSelector(cp)) {
      out += _blinkTextPresentation.VS15;
      changed = true;
    }
  }

  return changed ? out : str;
}

// Companion to the span.emoji rule in term.css. Double width emoji render
// through Apple Color Emoji, whose advance is wider than the two cells hterm
// reserves, so rows overrun the grid and trailing text wraps. Measure a
// reference emoji against the real cell width and publish the correction as a
// custom property.
var _blinkEmojiScale = {
  el: null,
  font: null,

  update: function() {
    var screen = document.querySelector('x-screen');
    if (!screen) {
      return;
    }

    var font = getComputedStyle(screen).font;
    if (!font || this.font === font) {
      return;
    }
    this.font = font;

    if (!this.el) {
      this.el = document.createElement('span');
      this.el.style.cssText =
        'position:absolute;top:-9999px;left:-9999px;visibility:hidden;' +
        'white-space:pre;padding:0;margin:0;border:0;';
      document.body.appendChild(this.el);
    }
    this.el.style.font = font;

    this.el.textContent = 'M';
    var cell = this.el.getBoundingClientRect().width;
    // U+1F600 is Emoji_Presentation=Yes, so it always takes the colour font.
    this.el.textContent = '😀';
    var emoji = this.el.getBoundingClientRect().width;

    if (!cell || !emoji) {
      return;
    }

    // Only correct an overflow; never enlarge a glyph that already fits.
    var scale = Math.min(1, (cell * 2) / emoji);
    document.documentElement.style.setProperty(
      '--blink-emoji-scale', String(Math.round(scale * 1000) / 1000));
  },
};

// hterm measures width one codepoint at a time, so an emoji ZWJ sequence such
// as U+1F9D1 ZWJ U+1F373 counts as four columns. tmux and other modern
// terminals treat it as one two column grapheme, so a status line they budget
// to fit renders too wide here and the tail wraps onto the next row.
//
// Count by grapheme cluster instead. Only strings that actually contain a
// joiner take this path; everything else keeps hterm's original arithmetic.
// Falls back entirely when Intl.Segmenter is unavailable.
var _BLINK_JOINERS =
  /[‍️\u{1F3FB}-\u{1F3FF}\u{1F1E6}-\u{1F1FF}\u{E0020}-\u{E007F}]/u;

var _blinkGrapheme = {
  seg: (typeof Intl !== 'undefined' && Intl.Segmenter)
    ? new Intl.Segmenter(undefined, { granularity: 'grapheme' })
    : null,

  needed: function(str) {
    return !!this.seg && _BLINK_JOINERS.test(str);
  },

  // A cluster holding any double width codepoint occupies two cells, matching
  // tmux. Otherwise sum the parts, which keeps combining marks at zero.
  clusterWidth: function(cluster) {
    var width = 0;
    var wide = false;
    for (var i = 0; i < cluster.length; ) {
      var cp = cluster.codePointAt(i);
      var cw = lib.wc.charWidth(cp);
      if (cw === 2) {
        wide = true;
      }
      width += cw;
      i += cp <= 0xFFFF ? 1 : 2;
    }
    return wide ? 2 : width;
  },

  segments: function(str) {
    return Array.from(this.seg.segment(str));
  },
};

lib.wc.strWidth_original = lib.wc.strWidth;
lib.wc.strWidth = function(str) {
  if (!_blinkGrapheme.needed(str)) {
    return lib.wc.strWidth_original(str);
  }
  var width = 0;
  var segments = _blinkGrapheme.segments(str);
  for (var i = 0; i < segments.length; i++) {
    width += _blinkGrapheme.clusterWidth(segments[i].segment);
  }
  return width;
};

lib.wc.substr_original = lib.wc.substr;
lib.wc.substr = function(str, start, opt_width) {
  if (!_blinkGrapheme.needed(str)) {
    return lib.wc.substr_original(str, start, opt_width);
  }

  var segments = _blinkGrapheme.segments(str);
  var i = 0;
  var width = 0;

  // Advance while the next cluster still fits entirely before `start`.
  for (; i < segments.length; i++) {
    var cw = _blinkGrapheme.clusterWidth(segments[i].segment);
    if (width + cw > (start || 0)) {
      break;
    }
    width += cw;
  }

  var from = i < segments.length ? segments[i].index : str.length;
  if (opt_width == null) {
    return str.substr(from);
  }

  var taken = 0;
  var to = from;
  for (var j = i; j < segments.length; j++) {
    var w = _blinkGrapheme.clusterWidth(segments[j].segment);
    if (taken + w > opt_width) {
      break;
    }
    taken += w;
    to = segments[j].index + segments[j].segment.length;
  }
  return str.substring(from, to);
};

hterm.TextAttributes.splitWidecharString_original =
  hterm.TextAttributes.splitWidecharString;
hterm.TextAttributes.splitWidecharString = function(str) {
  if (!_blinkGrapheme.needed(str)) {
    return hterm.TextAttributes.splitWidecharString_original(str);
  }

  var out = [];
  var plain = '';
  var plainWidth = 0;
  var ascii = true;

  function flush() {
    if (!plain) {
      return;
    }
    out.push({ str: plain, asciiNode: ascii, wcStrWidth: plainWidth });
    plain = '';
    plainWidth = 0;
    ascii = true;
  }

  var segments = _blinkGrapheme.segments(str);
  for (var i = 0; i < segments.length; i++) {
    var cluster = segments[i].segment;
    var width = _blinkGrapheme.clusterWidth(cluster);

    if (width === 2) {
      flush();
      // Keeping the whole cluster in one node also lets WebKit compose the
      // joined glyph, instead of drawing each part separately.
      out.push({
        str: cluster, wcNode: true, asciiNode: false, wcStrWidth: 2,
      });
    } else {
      plain += cluster;
      plainWidth += width;
      if (cluster.codePointAt(0) > 127) {
        ascii = false;
      }
    }
  }
  flush();

  return out;
};

hterm.Terminal.prototype.print_original = hterm.Terminal.prototype.print;

hterm.Terminal.prototype.print = function(str) {
  _blinkEmojiScale.update();
  hterm.Terminal.prototype.print_original.call(
    this, _blinkForceTextPresentation(str));
};
