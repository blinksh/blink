//
//  TermJS.h
//  Blink
//
//  Created by Yury Korolev on 1/18/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#ifndef TermJS_h
#define TermJS_h

NSString *_encodeString(NSString *str)
{
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[ str ] options:0 error:nil];
  return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

NSString *term_init()
{
  return @"term_init();";
}

NSString *term_write(NSString *data) {
  return [NSString stringWithFormat:@"term_write(%@[0]);", _encodeString(data)];
}

NSString *term_clear()
{
  return @"term_clear();";
}

NSString *term_reset()
{
  return @"term_reset();";
}

NSString *term_focus()
{
  return @"term_focus();";
}

NSString *term_blur()
{
  return @"term_blur();";
}

NSString *term_setWidth(NSInteger count)
{
  return [NSString stringWithFormat:@"term_setWidth(\"%ld\");", (long)count];
}

NSString *term_increaseFontSize()
{
  return @"term_increaseFontSize();";
}

NSString *term_decreaseFontSize()
{
  return @"term_decreaseFontSize();";
}

NSString *term_resetFontSize()
{
  return @"term_resetFontSize();";
}

NSString *term_scale(CGFloat scale)
{
  return [NSString stringWithFormat:@"term_scale(%f);", scale];
}

NSString *term_setFontSize(NSNumber *newSize)
{
  return [NSString stringWithFormat:@"term_setFontSize(\"%@\");", newSize];
}

NSString *term_getCurrentSelection()
{
  return @"term_getCurrentSelection();";
}

NSString *term_setCursorBlink(BOOL state)
{
  return [NSString stringWithFormat:@"term_setCursorBlink(%@)", state ? @"true" : @"false"];
}

NSString *term_setFontFamily(NSString *family)
{
  return [NSString stringWithFormat:@"term_setFontFamily(%@[0]);", _encodeString(family)];
}

NSString *term_appendUserCss(NSString *css)
{
  return [NSString stringWithFormat:@"term_appendUserCss(%@[0])", _encodeString(css)];
}

NSString *term_cleanSelection()
{
  return @"term_cleanSelection();";
}

NSString *term_modifySelection(NSString *direction, NSString *granularity)
{
  return [NSString stringWithFormat:@"term_modifySelection(%@[0], %@[0])", _encodeString(direction), _encodeString(granularity)];
}

NSString *term_modifySideSelection()
{
  return @"term_modifySideSelection();";
}


#endif /* TermJS_h */
