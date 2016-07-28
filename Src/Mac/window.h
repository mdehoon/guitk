#include <Python.h>

extern PyTypeObject WindowType;

@interface Window : NSWindow
{
    PyObject* object;
}
@property PyObject* object;
@end
