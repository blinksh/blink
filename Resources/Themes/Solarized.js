var base03 =     "#002b36";
var base02 =     "#073642";
var base01 =     "#586e75";
var base00 =     "#657b83";
var base0 =      "#839496";
var base1 =      "#93a1a1";
var base2 =      "#eee8d5";
var base3 =      "#fdf6e3";
var yellow =     "#b58900";
var orange =     "#cb4b16";
var red =        "#dc322f";
var magenta =    "#d33682";
var violet =     "#6c71c4";
var blue =       "#268bd2";
var cyan =       "#2aa198";
var green =      "#859900";

term_set('color-palette-overrides',
		 [ base02 , red     , green  , yellow,
		   blue     , magenta , cyan   , base2,
		   base03   , orange  , base01 , base00,
		   base0    , violet  , base1  , base3 ]);

term_set('cursor-color', 'rgba(255, 255, 255, 0.3)');
term_set('cursor-blink', false);
term_set('foreground-color', base0);
term_set('background-color', base03);
