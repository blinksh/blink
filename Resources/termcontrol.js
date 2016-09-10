var write_to_term = function(data) {
    t.io.print(data);
}
var sigwinch = function() {
    // This was removed as in theory the next resize would also take care of it.
    // It looks like under certain scenarios there is a race condition under which different sizes are
    // sent through different events on hterm and here included. This ensures that we take care of the
    // event chain ourselves.
    var screen = document.getElementsByTagName("iframe")[0].contentWindow.document.getElementsByTagName("x-screen")[0];
    var view_w = window.innerWidth;
    var view_h = window.innerHeight;
    screen.style.width = view_w;
    screen.style.height = view_h;

    // This was done to fix the SplitView getting stuck.
    // It shouldn't be necessary anymore, but it makes transitions smoother too.
    var termWindow = document.getElementsByTagName("iframe")[0].contentWindow;
    termWindow.resizeTo(window.innerWidth, window.innerHeight);
  
    t.scrollPort_.onResize_(null);
}

window.addEventListener('resize', sigwinch);

var increaseTermFontSize = function() {
    var size = t.getFontSize();
    t.setFontSize(++size);
}
var decreaseTermFontSize = function() {
    var size = t.getFontSize();
    t.setFontSize(--size);
}
var resetTermFontSize = function() {
    t.setFontSize(0);
}

var scaleTermStart = function() {
    this.fontSize = t.getFontSize();
}
var scaleTerm = function(scale) {
    if (scale > 2.0) scale = 2.0;
    if (scale < 0.5) scale = 0.5;
    t.setFontSize(Math.floor(this.fontSize * scale));
    window.webkit.messageHandlers.interOp.postMessage({"op": "fontSizeChanged", "data": {size: t.getFontSize()}});
}
var setFontSize = function(size) {
    t.setFontSize(size);
}

var focusTerm = function() {
    t.onFocusChange_(true);
}
var blurTerm = function() {
    t.onFocusChange_(false);
}

var setWidth = function(columnCount) {
    t.setWidth(columnCount);
}

var loadFontFromCSS = function(cssPath, name) {
    WebFont.load({
	custom: {
	    families: [name],
	    urls: [cssPath]
	},
	context: t.scrollPort_.iframe_.contentWindow,
	active: function() { t.syncFontFamily() }
    });
    t.prefs_.set('font-family', name);
}
