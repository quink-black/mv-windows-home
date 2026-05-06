#ifndef AXBRIDGING_H
#define AXBRIDGING_H

#include <ApplicationServices/ApplicationServices.h>
#include <CoreGraphics/CoreGraphics.h>

// Private but long-stable symbol exposed by the HIServices framework.
// Maps an AXUIElement representing a window to the corresponding CGWindowID
// returned by CGWindowListCopyWindowInfo. Used to correlate AX window objects
// with CGWindowList entries without relying on title matching.
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *windowID);

#endif
