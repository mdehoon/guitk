#include <Python.h>
#include "widgets.h"

@class Button;

extern PyTypeObject ButtonType;

typedef struct {
    PyObject_HEAD
    Button* button;
    PyObject* layout;
} PyButton;

@interface Button : WidgetView
{
    PyButton* object;
    NSButton* button;
    NSFont* font;
    NSString* text;
}
- (Button*)initWithObject:(PyButton*)obj;
- (void)setString:(const char*)text;
@end
