#include <Python.h>

extern PyTypeObject GridType;

@interface GridView : NSView
{
    PyObject* object;
}
@property PyObject* object;
- (void)frameDidChange:(NSNotification *)notification;
@end

typedef struct {
    PyObject_HEAD
    GridView* view;
    unsigned int nrows;
    unsigned int ncols;
    PyObject*** objects;
} GridObject;
