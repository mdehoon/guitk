#include <Python.h>
#include <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

CFStringRef PyString_AsCFString(const PyObject* object);
PyObject* PyString_FromCFString(const CFStringRef text);
int string_converter(PyObject* argument, CFStringRef* pointer);
