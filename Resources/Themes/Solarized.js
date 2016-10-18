base03 =     "#001E27";
base02 =     "#415257";
base01 =     "#586e75";
base00 =     "#657b83";
base0 =      "#839496";
base1 =      "#93a1a1";
base2 =      "#eee8d5";
base3 =      "#fdf6e3";
yellow =     "#b58900";
orange =     "#cb4b16";
red =        "#dc322f";
magenta =    "#d33682";
violet =     "#6c71c4";
blue =       "#268bd2";
cyan =       "#2aa198";
green =      "#859900";

t.prefs_.set('color-palette-overrides',
		 [ base03 , red     , green  , yellow,
		   blue     , magenta , cyan   , base2,
		   base02   , orange  , base01 , base00,
		   base0    , violet  , base1  , base3 ]);

t.prefs_.set('cursor-color', 'rgba(255, 255, 255, 0.3)');
t.prefs_.set('cursor-blink', false);
t.prefs_.set('foreground-color', base0);
t.prefs_.set('background-color', base03);
