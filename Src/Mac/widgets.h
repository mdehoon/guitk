#include <Python.h>
#include <Cocoa/Cocoa.h>

@interface WidgetView : NSView
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (WidgetView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
@end

typedef struct {
    PyObject_HEAD
    WidgetView* view;
} WidgetObject;

extern PyTypeObject WidgetType;
extern PyTypeObject LayoutType;
extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
