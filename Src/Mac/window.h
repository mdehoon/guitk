#include <Python.h>

extern PyTypeObject WindowType;

@interface Window : NSWindow <NSWindowDelegate>
{
    PyObject* object;
}
@property PyObject* object;
- (void)windowWillClose:(NSNotification *)notification;
@end
