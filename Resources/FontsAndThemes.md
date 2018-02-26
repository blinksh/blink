# Create your own Fonts & Themes

With [Blink Shell](http://blink.sh) you can have your terminal, your way. That's why we have built in a simple way to create and add themes and fonts to your terminal. Themes are JS code that can modify colors and cursor behavior, and fonts are just CSS that Blink will download for you. And don't forget to share them with others too!

Being web based gives us an easy way to make Blink more extensible. We will continue to improve it and to expand it to other things like plugins. Send us your suggestions [@BlinkShell](https://twitter.com/blinkshell)!

* Create your Shell theme (JS) or font (CSS)
* Download it from Blink
* Share it with others!

## Create a Shell Theme

```javascript
black       = '#000000';
red         = '#F25A00'; // red
green       = '#6AAF19'; // green
yellow      = '#9F9F8F'; // yellow
blue        = '#66D9EF'; // blue
magenta     = '#AE81FF'; // pink
cyan        = '#28C6E4'; // cyan
white       = '#ffffff'; // light gray
lightBlack  = '#C2E8FF'; // medium gray
lightRed    = '#FD971F'; // red
lightGreen  = '#529B2F'; // green
lightYellow = '#9F9F8F'; // yellow
lightBlue   = '#66D9EF'; // blue
lightMagenta= '#F92672'; // pink
lightCyan   = '#28C6E4'; // cyan
lightWhite  = '#E0E0E0'; // white

t.prefs_.set('color-palette-overrides',
                 [ black , red     , green  , yellow,
                  blue     , magenta , cyan   , white,
                  lightBlack   , lightRed  , lightGreen , lightYellow,
                  lightBlue    , lightMagenta  , lightCyan  , lightWhite ]);

t.prefs_.set('cursor-color', 'rgba(0, 0, 0, 0.5)');
t.prefs_.set('foreground-color', '#000000');
t.prefs_.set('background-color', white);
```

### Colors
Back in the old days terminals were only able to display 16 colors. Then more complex ones came with new sequences for 256 colors and nowadays there are even sequences to represent TrueColor.
Terminal Emulators and applications still rely on the basic 16 color sequences for their applications. This is done by defining a set of basic colors, and then a "highlighted" / "accented" version of those.
```javascript
t.prefs_.set('color-palette-overrides',
                 [ black , red     , green  , yellow,
                  blue     , magenta , cyan   , white,
                  lightBlack   , lightRed  , lightGreen , lightYellow,
                  lightBlue    , lightMagenta  , lightCyan  , lightWhite ]);
```
### Foreground / Background
In addition to the previous 16 colors, foreground and background colors can also be defined. This is usually done to improve contrast.
```javascript
t.prefs_.set('foreground-color', '#000000');
t.prefs_.set('background-color', white);
```

### Cursor
You can configure the cursor for the theme too, applying color and other effects.
```javascript
t.prefs_.set('cursor-color', 'rgba(0, 0, 0, 0.5)');
t.prefs_.set('cursor-blink', true);
```

## Create a Font
```css
@font-face {
    font-family: "Fira Code";
    font-style: normal;
    font-weight: 200;
    src: url(data:font/woff;charset-utf-8;base64,<base64 dump>);
}
@font-face {
    font-family: "Fira Code";
    font-style: normal;
    font-weight: 400;
    src: url(data:font/woff;charset-utf-8;base64,<base64 dump>);
}
@font-face {
    font-family: "Fira Code";
    font-weight: 600;
    src: url('fira code medium.ttf' format('truetype'));
}
@font-face {
    font-family: "Fira Code";
    font-weight: 800;
    src: url('fira code bold.woff' format('woff'));
}
```

Fonts are defined as a stylesheet using @font-face's structure. Make sure the font-family corresponds to the name you are giving when saving it. You can link your font to a valid URL, or you can embed it as a full Base64 representation. We suggest you add also the different variants available for weight.
* 200 Light or Thin.
* 400 Normal or Regular.
* 500 Medium.
* 700 Bold.

Read more about [font-face](https://css-tricks.com/snippets/css/using-font-face/)

## Installing on Blink.

As Blink Shell is a web terminal, themes and fonts are applied over the web and downloaded to your device for faster loading. We recommend GitHub as the fastest way to do that, but any file server will do.

- Create a Gist and get the "raw" URL for it.
- Go to Settings -> Appeareance -> (New Font || New Theme) -> Paste the URL and download it -> Save and select it from the list.

## Share it with others!

Have a great theme/font that would like to share with other Blink users? Go to the corresponding [theme gallery](https://github.com/blinksh/themes)/[font gallery](https://github.com/blinksh/fonts) and send us a PR :)






