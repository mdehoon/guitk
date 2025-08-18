#include <Python.h>


static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,  
    .m_name = "events_tcltk",               
    .m_doc = "events_tcltk module",        
    .m_size = -1,                     
};

PyObject* PyInit_events(void)
{
    return PyModule_Create(&moduledef);
}   
