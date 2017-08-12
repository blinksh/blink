var write_to_term = function(data) {
  term.write(data);
  term.restartCursorBlinking();
};

var sigwinch = function() {
  // This was removed as in theory the next resize would also take care of it.
  // It looks like under certain scenarios there is a race condition under which different sizes are
  // sent through different events on hterm and here included. This ensures that we take care of the
  // event chain ourselves.
  //    var screen = document.getElementsByTagName("iframe")[0].contentWindow.document.getElementsByTagName("x-screen")[0];
  //    var view_w = window.innerWidth;
  //    var view_h = window.innerHeight;
  //    screen.style.width = view_w;
  //    screen.style.height = view_h;
  //
  //    // This was done to fix the SplitView getting stuck.
  //    // It shouldn't be necessary anymore, but it makes transitions smoother too.
  //    var termWindow = document.getElementsByTagName("iframe")[0].contentWindow;
  //    termWindow.resizeTo(window.innerWidth, window.innerHeight);
  //
  //    t.scrollPort_.onResize_(null);
};

window.onresize = function() {
  term.fit();
};

var getTerminalNode = function() {
  return document.getElementsByClassName('terminal')[0];
};

var getFontSize = function() {
  var el = getTerminalNode();
  var style = window.getComputedStyle(el, null).getPropertyValue('font-size');
  var fontSize = parseFloat(style);
  return fontSize;
};

var setFontSize = function(size) {
  var el = getTerminalNode();
  el.style.fontSize = size + 'px';
  setTimeout(function() {
    term.fit();
  }, 200);
};

var increaseTermFontSize = function() {
  var size = getFontSize();
  setFontSize(++size);
};
var decreaseTermFontSize = function() {
  var size = getFontSize();
  setFontSize(--size);
};
var resetTermFontSize = function() {
  //    setFontSize(0);
};

var scaleTermStart = function() {
  this.fontSize = getFontSize();
};
var scaleTerm = function(scale) {
  if (scale > 2.0) scale = 2.0;
  if (scale < 0.5) scale = 0.5;
  setFontSize(Math.floor(this.fontSize * scale));
};
//var setFontSize = function(size) {
//    t.setFontSize(size);
//    window.webkit.messageHandlers.interOp.postMessage({"op": "fontSizeChanged", "data": {"size": t.getFontSize()}});
//}

var setCursorBlink = function(state) {
  term.setCursorBlinking(state);
};

var focusTerm = function() {
  term.focus();
};
var blurTerm = function() {
  term.blur();
};

var setWidth = function(columnCount) {
  //    t.setWidth(columnCount);
};

var loadFontFromCSS = function(cssPath, name) {
  //  t.prefs_.set('user-css', "data:text/css;utf-8,* { font-feature-settings: \"liga\" 0; }");

  WebFont.load({
    custom: {
      families: [name],
      urls: [cssPath],
    },
  });
  //  context: t.scrollPort_.iframe_.contentWindow,
  //  active: function() { t.syncFontFamily() }
  //    });
  //    t.prefs_.set('font-family', name + ", Menlo");
  getTerminalNode().style.fontFamily = name + ', Menlo';
};

var clear = function() {
  term.clear();
};

var reset = function() {
  term.reset();
};

var _config = {};
var t = {};
t.prefs_ = {};
t.prefs_.set = function(key, value) {
  _config[key] = value;
}

var styleNode = null;

function applyPrefs() {
  var colors = _config['color-palette-overrides'];
  var cssLines = [];
  if (colors) {
    for (var i = 0; i < colors.length; i++) {
      cssLines.push(".terminal .xterm-color-" + i + " { color: " + colors[i]+ ";}")
      cssLines.push(".terminal .xterm-bg-color-" + i + " { background-color: " + colors[i]+ ";}")
    }
  }
  
  var fgColor = _config['foreground-color'];
  if (fgColor) {
    cssLines.push(".terminal { color: " + fgColor + ";}");
    
  }
  
  var bgColor = _config['background-color'];
  if (bgColor) {
    cssLines.push(".terminal { background-color: " + bgColor + ";}");
    cssLines.push(".terminal .xterm-viewport { background-color: " + bgColor + ";}");
  }
  
  var head = document.head
  var style = document.createElement('style');

  style.type = 'text/css';
  style.appendChild(document.createTextNode(cssLines.join("\n")));

  head.appendChild(style);

  if (styleNode) {
    styleNode.remove();
  }
  styleNode = style;
  resetPrefs();
}

function resetPrefs() {
  _config = {};
}

//hterm.copySelectionToClipboard = function(document) {
////    window.webkit.messageHandlers.interOp.postMessage({"op": "copy", "data":{"content": document.getSelection().toString()}});
//}
