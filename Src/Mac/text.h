#include <Python.h>
#include <Cocoa/Cocoa.h>

CFStringRef PyString_AsCFString(const PyObject* object);
PyObject* PyString_FromCFString(const CFStringRef text);
NSString* PyString_AsNSString(PyObject* object);
PyObject* PyString_FromNSString(const NSString* text);
