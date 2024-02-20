#include <Cocoa/Cocoa.h>
#include "widgets.h"
#include "window.h"
#include "colors.h"
#include "text.h"


@interface Listbox : NSTableView <NSTableViewDelegate, NSTableViewDataSource>
{
    PyObject* _object;
}
@property (readonly) PyObject* object;
- (Listbox*)initWithObject:(PyObject*)obj;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
@end

typedef struct {
    WidgetObject widget;
    NSFont* font;
    ColorObject* background;
    NSMutableArray* array;
} ListboxObject;

@implementation Listbox

- (PyObject*)object
{
    return (PyObject*)_object;
}

- (Listbox*)initWithObject:(PyObject*)object
{
    NSTableColumn* column;
    NSRect rect;
    rect.origin.x = 10;
    rect.origin.y = 10;
    rect.size.width = 100;
    rect.size.height = 100;
    _object = object; /* Should come before creating the NSTableView */
    self = [super initWithFrame: rect];
    [self setAutoresizingMask: NSViewMinXMargin
                             | NSViewWidthSizable
                             | NSViewMaxXMargin
                             | NSViewMinYMargin
                             | NSViewHeightSizable
                             | NSViewMaxYMargin];
    column = [[NSTableColumn alloc] initWithIdentifier:@""];
    [[column headerCell] setStringValue:@"Column 1"];
    [self addTableColumn:column];

    [self setUsesAlternatingRowBackgroundColors:YES];
    [self setGridStyleMask:NSTableViewSolidVerticalGridLineMask];
    [self setDelegate:self];
    [self setDataSource:self];
    [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
    return self;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
     NSString *aString;
     ListboxObject* listbox = (ListboxObject*)_object;
     aString = [listbox->array objectAtIndex:rowIndex];
     return aString;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
   ListboxObject* listbox = (ListboxObject*)_object;
   long recordCount = [listbox->array count];
   return recordCount;
}
@end

static PyObject*
Listbox_new(PyTypeObject *type, PyObject *args, PyObject *kwds)
{
    ListboxObject *self = (ListboxObject*) WidgetType.tp_new(type, args, kwds);
    if (!self) return NULL;
    self->background = NULL;

    Py_INCREF(Py_None);
    return (PyObject*)self;
}

static int
Listbox_init(ListboxObject *self, PyObject *args, PyObject *keywords)
{
    Listbox *listbox;
    PyObject* multiple = Py_False;
    WidgetObject* widget;
    NSColor* color;

    static char* kwlist[] = {"multiple", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, keywords, "|O", kwlist,
                                     &multiple))
        return -1;

    if (multiple!=Py_True && multiple!=Py_False) {
        PyErr_SetString(PyExc_ValueError, "multiple should be True or False.");
        return -1;
    }
    self->array = [[NSMutableArray alloc] init];

    listbox = [[Listbox alloc] initWithObject: (PyObject*)self];
    if (multiple==Py_True) listbox.allowsMultipleSelection = YES;
    widget = (WidgetObject*)self;
    widget->view = listbox;

    Py_INCREF(systemWindowBackgroundColor);
    Py_XDECREF(self->background);
    self->background = systemWindowBackgroundColor;

    color = [NSColor colorWithCalibratedRed: self->background->rgba[0] / 255.
                                      green: self->background->rgba[1] / 255.
                                       blue: self->background->rgba[2] / 255.
                                      alpha: self->background->rgba[3] / 255.];
    listbox.backgroundColor = color;
    listbox.usesAlternatingRowBackgroundColors = NO;


    return 0;
}

static PyObject*
Listbox_repr(ListboxObject* self)
{
    WidgetObject* widget = (WidgetObject*) self;
    NSView* view = widget->view;
    return PyUnicode_FromFormat("Listbox object %p wrapping NSTableView %p",
                               (void*) self, (void*)view);
}

static void
Listbox_dealloc(ListboxObject* self)
{
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    if (listbox)
    {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [listbox release];
        [pool release];
    }
    Py_XDECREF(self->background);
    Py_TYPE(self)->tp_free((PyObject*)self);
}

static PyObject*
Listbox_set_frame(ListboxObject* self, PyObject *args)
{
    float x0;
    float y0;
    float x1;
    float y1;
    NSPoint position;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* listbox = widget->view;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ffff", &x0, &y0, &x1, &y1))
        return NULL;

    position.x = x0;
    position.y = y0;
    [listbox setFrameOrigin: position];
    size.width = x1 - x0;
    size.height = y1 - y0;
    [listbox setFrameSize: size];

    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Listbox_get_size(ListboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSRect frame;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* listbox = widget->view;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    frame = [listbox frame];
    width = frame.size.width;
    height = frame.size.height;
    return Py_BuildValue("ff", width, height);
}

static PyObject*
Listbox_set_size(ListboxObject* self, PyObject *args)
{
    float width;
    float height;
    NSSize size;
    WidgetObject* widget = (WidgetObject*)self;
    NSView* listbox = widget->view;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "ff", &width, &height)) return NULL;
    if (width < 0 || height < 0) {
        PyErr_SetString(PyExc_RuntimeError, "width and height should be non-negative");
        return NULL;
    }
    size.width = width;
    size.height = height;
    [listbox setFrameSize: size];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Listbox_insert(ListboxObject* self, PyObject *args)
{
    CFStringRef text;
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    Window* window = (Window*) [listbox window];
    PyObject* value;
    int index;
    long n;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "iO", &index, &value)) return NULL;
    n = [self->array count];
    if (index < 0) index += n;
    if (index < 0 || index >= n) {
        PyErr_SetString(PyExc_IndexError, "index out of bounds");
        return NULL;
    }
    text = PyString_AsCFString(value);
    if (!text) return NULL;
    [self->array insertObject: (NSString*) text atIndex: index];
    [listbox reloadData];
    [listbox requestLayout];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Listbox_append(ListboxObject* self, PyObject *args)
{
    CFStringRef text;
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    Window* window = (Window*) [listbox window];
    PyObject* value;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "O", &value)) return NULL;
    text = PyString_AsCFString(value);
    if (!text) return NULL;
    [self->array addObject: (NSObject*) text];
    [listbox reloadData];
    [listbox requestLayout];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyObject*
Listbox_delete(ListboxObject* self, PyObject *args)
{
    int index;
    CFStringRef text;
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    Window* window = (Window*) [listbox window];
    long n;
    if (!listbox) {
        PyErr_SetString(PyExc_RuntimeError, "listbox has not been initialized");
        return NULL;
    }
    if(!PyArg_ParseTuple(args, "i", &index)) return NULL;
    n = [self->array count];
    if (index < 0) index += n;
    if (index < 0 || index >= n) {
        PyErr_SetString(PyExc_IndexError, "index out of bounds");
        return NULL;
    }
    text = (CFStringRef) self->array[index];
    CFRelease(text);
    [self->array removeObjectAtIndex: index];
    [listbox reloadData];
    [listbox requestLayout];
    Py_INCREF(Py_None);
    return Py_None;
}

static PyMethodDef Listbox_methods[] = {
    {"set_frame",
     (PyCFunction)Listbox_set_frame,
     METH_VARARGS,
     "Sets the size and position of the listbox."
    },
    {"get_size",
     (PyCFunction)Listbox_get_size,
     METH_NOARGS,
     "Returns the size of the listbox."
    },
    {"set_size",
     (PyCFunction)Listbox_set_size,
     METH_VARARGS,
     "Sets the size of the listbox."
    },
    {"append",
     (PyCFunction)Listbox_append,
     METH_VARARGS,
     "Appends one item to the list."
    },
    {"insert",
     (PyCFunction)Listbox_insert,
     METH_VARARGS,
     "Inserts one item into the list."
    },
    {"delete",
     (PyCFunction)Listbox_delete,
     METH_VARARGS,
     "Deletes one item from the list."
    },
    {NULL}  /* Sentinel */
};

static PyObject* Listbox_get_minimum_size(ListboxObject* self, void* closure)
{
    NSInteger i;
    double width = 0.0;
    double height = 0.0;
    NSSize size;
    NSView* cell;
    WidgetObject* widget = (WidgetObject*) self;
    NSView* view = widget->view;
    NSTableView* listbox = (NSTableView*)view;
    for (i = 0; i < listbox.numberOfRows; i++) {
        cell = [listbox viewAtColumn:0 row:i makeIfNecessary:YES];
        size = cell.frame.size;
        if (size.width > width) width = size.width;
        height += size.height;
    }
    return Py_BuildValue("dd", width, height);
}

static char Listbox_minimum_size__doc__[] = "minimum size needed to show the listbox.";

static PyObject* Listbox_get_selected(ListboxObject* self, void* closure)
{
    Listbox* listbox;
    WidgetObject* widget;
    NSUInteger index;
    NSUInteger count;
    NSIndexSet* indices;
    PyObject* tuple;
    PyObject* item;
    Py_ssize_t i = 0;
    widget = (WidgetObject*) self;
    listbox = (Listbox*)(widget->view);
    indices = [listbox selectedRowIndexes];
    count = indices.count;
    index = [indices firstIndex];
    tuple = PyTuple_New(count);
    if (!tuple) return NULL;
    while (index != NSNotFound)
    {
        item = PyLong_FromLong(index);
        if (!item) {
            while (i > 0) {
                i--;
                item = PyTuple_GET_ITEM(tuple, i);
                Py_DECREF(item);
            }
            Py_DECREF(tuple);
            return NULL;
        }
        PyTuple_SET_ITEM(tuple, i, item);
        index = [indices indexGreaterThanIndex: index];
        i++;
    }
    return tuple;
}

static int
Listbox_set_selected(ListboxObject* self, PyObject* tuple, void* closure)
{
    Listbox* listbox;
    WidgetObject* widget;
    NSMutableIndexSet* indices;
    Py_ssize_t i;
    Py_ssize_t size;
    PyObject* item;
    long index;
    long count;
    if (!PyTuple_Check(tuple)) {
        PyErr_SetString(PyExc_ValueError, "expected a tuple.");
        return -1;
    }
    widget = (WidgetObject*) self;
    listbox = (Listbox*)(widget->view);
    indices = [NSMutableIndexSet indexSet];
    size = PyTuple_GET_SIZE(tuple);
    count = [self->array count];
    for (i = 0; i < size; i++) {
        item = PyTuple_GET_ITEM(tuple, i);
        index = PyLong_AsLong(item);
        if (index == -1 && PyErr_Occurred()) {
            PyErr_SetString(PyExc_ValueError, "expected a tuple of integers.");
            return -1;
        }
        if (index < 0) index += count;
        if (index < 0 || index >= count) {
            PyErr_SetString(PyExc_IndexError, "index out of bounds.");
            return -1;
        }
        [indices addIndex: index];
    }
    [listbox selectRowIndexes: indices byExtendingSelection: NO];
    return 0;
}

static char Listbox_selected__doc__[] = "indices of currently selected items.";

static PyObject* Listbox_get_background(ListboxObject* self, void* closure)
{
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    NSColor* c = [listbox backgroundColor];
    fprintf(stderr, "[listbox backgroundColor] returns %f, %f, %f, %f\n",
        [c redComponent],
        [c greenComponent],
        [c blueComponent],
        [c alphaComponent]);

    Py_INCREF(self->background);
    return (PyObject*) self->background;
}

static int
Listbox_set_background(ListboxObject* self, PyObject* value, void* closure)
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    NSColor* color;
    WidgetObject* widget = (WidgetObject*)self;
    Listbox* listbox = (Listbox*) widget->view;
    if (!Py_IS_TYPE(value, &ColorType)) {
        PyErr_SetString(PyExc_ValueError, "expected a Color object");
        return -1;
    }
    Py_INCREF(value);
    Py_DECREF(self->background);
    self->background = (ColorObject*) value;
    red = self->background->rgba[0] / 255.;
    green = self->background->rgba[1] / 255.;
    blue = self->background->rgba[2] / 255.;
    alpha = self->background->rgba[3] / 255.;
    color = [NSColor colorWithCalibratedRed: red
                                      green: green
                                       blue: blue
                                      alpha: alpha];
    listbox.backgroundColor = color;
    listbox.needsDisplay = YES;
    return 0;
}

static char Listbox_background__doc__[] = "background color.";

static PyGetSetDef Listbox_getseters[] = {
    {"minimum_size", (getter)Listbox_get_minimum_size, (setter)NULL, Listbox_minimum_size__doc__, NULL},
    {"selected", (getter)Listbox_get_selected, (setter)Listbox_set_selected, Listbox_selected__doc__, NULL},
    {"background", (getter)Listbox_get_background, (setter)Listbox_set_background, Listbox_background__doc__, NULL},
    {NULL}  /* Sentinel */
};

static char Listbox_doc[] =
"A Listbox object wraps a Cocoa NSTableView object.\n";

PyTypeObject ListboxType = {
    PyVarObject_HEAD_INIT(NULL, 0)
    "_guitk.Listbox",            /* tp_name */
    sizeof(ListboxObject),       /* tp_basicsize */
    0,                          /* tp_itemsize */
    (destructor)Listbox_dealloc, /* tp_dealloc */
    0,                          /* tp_print */
    0,                          /* tp_getattr */
    0,                          /* tp_setattr */
    0,                          /* tp_compare */
    (reprfunc)Listbox_repr,      /* tp_repr */
    0,                          /* tp_as_number */
    0,                          /* tp_as_sequence */
    0,                          /* tp_as_mapping */
    0,                          /* tp_hash */
    0,                          /* tp_call */
    0,                          /* tp_str */
    0,                          /* tp_getattro */
    0,                          /* tp_setattro */
    0,                          /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,        /* tp_flags */
    Listbox_doc,                 /* tp_doc */
    0,                          /* tp_traverse */
    0,                          /* tp_clear */
    0,                          /* tp_richcompare */
    0,                          /* tp_weaklistoffset */
    0,                          /* tp_iter */
    0,                          /* tp_iternext */
    Listbox_methods,             /* tp_methods */
    0,                          /* tp_members */
    Listbox_getseters,           /* tp_getset */
    &WidgetType,                /* tp_base */
    0,                          /* tp_dict */
    0,                          /* tp_descr_get */
    0,                          /* tp_descr_set */
    0,                          /* tp_dictoffset */
    (initproc)Listbox_init,      /* tp_init */
    0,                          /* tp_alloc */
    Listbox_new,                 /* tp_new */
};
