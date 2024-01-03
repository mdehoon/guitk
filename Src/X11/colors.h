#include <Python.h>
#include <stdbool.h>


typedef struct {
    PyObject_HEAD
    unsigned short rgba[4];
} ColorObject;

extern PyTypeObject ColorType;

extern ColorObject* transparent;
extern ColorObject* black;
extern ColorObject* systemTextColor;
extern ColorObject* systemWindowBackgroundColor;

extern bool _init_default_colors(void);
