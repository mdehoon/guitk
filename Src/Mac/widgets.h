#include <Python.h>
#include <Cocoa/Cocoa.h>


@interface View : NSView
- (BOOL)isFlipped;
@end

extern PyTypeObject WidgetType;

typedef struct {
    PyObject_HEAD
    View* view;
} WidgetObject;
