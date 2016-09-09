#include <Python.h>

extern PyTypeObject ColorType;
int Color_converter(PyObject* argument, void* address);
PyObject* Color_create(short rgba[4]);
