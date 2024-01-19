#include <Cocoa/Cocoa.h>
#include <Python.h>


@interface LabelView : NSView
{
    PyObject* _object;
}
@property(readonly) PyObject* object;
- (LabelView*)initWithFrame:(NSRect)rect withObject:(PyObject*)object;
- (BOOL)isFlipped;
- (void)drawRect:(NSRect)rect;
- (void)viewWillDraw;
@end
