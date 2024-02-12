#include <Python.h>
#include <Cocoa/Cocoa.h>

extern PyTypeObject WindowType;

@class Window;

typedef struct {
    PyObject_HEAD
    Window* window;
    BOOL layout_requested;
    BOOL is_key;
} WindowObject;

@interface Window : NSWindow <NSWindowDelegate>
{
    WindowObject* _object;
}
@property (readonly) WindowObject* object;
- (Window*)initWithContentRect: (NSRect)rect
                     styleMask: (NSUInteger)windowStyle
                        object: (WindowObject*)object;
- (void)windowWillClose:(NSNotification *)notification;
- (void)windowDidResize:(NSNotification *)notification;
- (void)requestLayout;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
@end
