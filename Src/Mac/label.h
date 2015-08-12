#include <Python.h>

extern PyTypeObject LabelType;

typedef struct {
    PyObject_HEAD
    NSTextField* label;
} Label;
