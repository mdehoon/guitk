#include <Python.h>

extern PyTypeObject WindowType;

@class Window;

typedef struct {
    PyObject_HEAD
    Window* window;
    PyObject* content;
    BOOL layout_requested;
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
- (void)requestLayout;
@end
