#include <Python.h>
#include <Cocoa/Cocoa.h>

extern PyTypeObject WindowType;

@class Window;

typedef struct {
    PyObject_HEAD
    Window* window;
    bool is_key;
} WindowObject;

@interface Window : NSWindow <NSWindowDelegate>
{
}
@property (nonatomic, assign) WindowObject* object;
- (Window*)initWithContentRect: (NSRect)rect
                     styleMask: (NSUInteger)windowStyle
                        object: (WindowObject*)object;
- (void)windowWillClose:(NSNotification *)notification;
- (void)windowDidBecomeKey:(NSNotification *)notification;
- (void)windowDidResignKey:(NSNotification *)notification;
@end
