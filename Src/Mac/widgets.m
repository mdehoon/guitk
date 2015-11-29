#include "widgets.h"

PyObject* widgets;

void initialize_widgets(void)
{
    widgets = PyTuple_New(2);
    Py_INCREF((PyObject*)(&GridItemType));
    Py_INCREF((PyObject*)(&GridType));
    PyTuple_SET_ITEM(widgets, 0, (PyObject*)(&GridItemType));
    PyTuple_SET_ITEM(widgets, 1, (PyObject*)(&GridType));
}
