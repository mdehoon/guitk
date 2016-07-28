#include <Python.h>

extern PyTypeObject WindowType;

@interface Window : NSWindow
{
    PyObject* object;
    BOOL closed;
}
@property PyObject* object;
@property BOOL closed;
@end
