#include <Python.h>

@class Label;

extern PyTypeObject LabelType;

typedef struct {
    PyObject_HEAD
    Label* label;
} PyLabel;

@interface Label : NSView
{
    PyLabel* object;
    NSFont* font;
    NSString* text;
    NSPoint position;
}
- (Label*)initWithObject:(PyLabel*)obj;
- (void)setString:(const char*)text;
- (void)drawRect:(NSRect)rect;
- (BOOL)pack:(NSRect*)cavity;
@end
