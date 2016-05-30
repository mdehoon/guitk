#include <Python.h>

@class Button;

extern PyTypeObject ButtonType;

typedef struct {
    PyObject_HEAD
    Button* button;
    PyObject* layout;
} PyButton;

@interface Button : NSButton
{
    PyButton* object;
    NSFont* font;
    NSString* text;
}
- (Button*)initWithObject:(PyButton*)obj;
- (void)setString:(const char*)text;
- (BOOL)pack:(NSRect*)cavity;
@end
