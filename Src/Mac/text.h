#include <Python.h>
#include <Cocoa/Cocoa.h>

CFStringRef PyString_AsCFString(const PyObject* object);
PyObject* PyString_FromCFString(const CFStringRef text);
int string_converter(PyObject* argument, CFStringRef* pointer);
NSString* PyString_AsNSString(PyObject* object);
