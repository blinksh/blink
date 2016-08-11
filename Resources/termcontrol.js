var write_to_term = function(data) {
    t.io.print(data);
}
var sigwinch = function() {
    var termWindow = document.getElementsByTagName("iframe")[0].contentWindow;
    termwindow.resizeTo(window.innerWidth, window.innerHeight);
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
    t.setFontSize(this.fontSize * scale);
}
var focusTerm = function() {
    t.onFocusChange_(true);
}
var blurTerm = function() {
    t.onFocusChange_(false);
}
