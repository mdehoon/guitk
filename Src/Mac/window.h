#include <Python.h>

extern PyTypeObject WindowType;

@interface Window : NSWindow
{
    PyObject* _object;
}
- (void)initWithContentRect:(NSRect)rect
                  styleMask:(NSUInteger)windowStyle
                     object:(PyObject*)object;
- (PyObject*)object;
@end
