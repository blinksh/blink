const UIKeyModifierAlphaShift = 1 << 16; // This bit indicates CapsLock
const UIKeyModifierShift = 1 << 17;
const UIKeyModifierControl = 1 << 18;
const UIKeyModifierAlternate = 1 << 19;
const UIKeyModifierCommand = 1 << 20;
const UIKeyModifierNumericPad = 1 << 21;

export function toUIKitFlags(e: KeyboardEvent, capsKey = true): number {
  let res = 0;
  if (e.shiftKey) {
    res |= UIKeyModifierShift;
  }
  if (e.ctrlKey) {
    res |= UIKeyModifierControl;
  }
  if (e.altKey) {
    res |= UIKeyModifierAlternate;
  }
  if (e.metaKey) {
    res |= UIKeyModifierCommand;
  }
  if (capsKey) {
    res |= UIKeyModifierAlphaShift;
  }
  return res;
}

export function UIKitFlagsToObject(
  flags: number,
): {shift: boolean, alt: boolean, ctrl: boolean, meta: boolean} {

  var shift = (flags & UIKeyModifierShift) == UIKeyModifierShift
  var alt = (flags & UIKeyModifierAlternate) == UIKeyModifierAlternate
  var ctrl = (flags & UIKeyModifierControl) == UIKeyModifierControl
  var meta = (flags & UIKeyModifierCommand) == UIKeyModifierCommand

  return {shift, alt, ctrl, meta}
}
