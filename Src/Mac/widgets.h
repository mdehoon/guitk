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


extern PyTypeObject WidgetType;

typedef struct {
    PyObject_HEAD
    WidgetView* view;
} WidgetObject;

@class GridView;

extern PyTypeObject LabelType;
extern PyTypeObject ButtonType;
extern PyTypeObject GridType;


typedef struct {
    PyObject_HEAD
    GridView* view;
    unsigned int nrows;
    unsigned int ncols;
    WidgetObject*** objects;
} GridObject;

@interface GridView : WidgetView
{
    BOOL layoutIsValid;
}
- (void)frameDidChange:(NSNotification *)notification;
- (void)doLayout;
- (void)invalidateLayout;
@end
