#include <Python.h>


typedef struct {
    PyObject_HEAD
    unsigned short rgba[4];
} ColorObject;

extern PyTypeObject ColorType;
int Color_converter(PyObject* argument, void* address);
PyObject* Color_create(short rgba[4]);

extern ColorObject* transparent;
extern ColorObject* black;
extern ColorObject* systemTextColor;
extern ColorObject* systemWindowBackgroundColor;

extern bool _init_default_colors(void);
