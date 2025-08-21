#!/usr/bin/env python

import os.path
import sys

try:
    from setuptools import setup
    from setuptools import Extension
except ImportError:
    sys.exit(
        "We need the Python library setuptools to be installed. "
        "Try running: python -m ensurepip"
    )

extensions = []

include_dirs = ['Src','Src/Generic']
if sys.platform == 'darwin':
    event_sources = ["Src/Mac/events.m",
              ]
    gui_sources = ["Src/Mac/gui.m",
                   "Src/Mac/window.m",
                   "Src/Mac/image.m",
                   "Src/Mac/text.m",
                   "Src/Mac/widgets.m",
                   "Src/Mac/layout.m",
                   "Src/Mac/font.m",
                   "Src/Mac/frame.m",
                   "Src/Mac/separator.m",
                   "Src/Mac/label.m",
                   "Src/Mac/button.m",
                   "Src/Mac/checkbox.m",
                   "Src/Mac/textbox.m",
                   "Src/Mac/listbox.m",
                   "Src/Mac/colors.m",
                   "Src/Mac/focus.m",
                  ]
    extra_link_args = ['-framework', 'Cocoa']
else:
    event_sources = ["Src/X11/events.c",
                    ]
    event_tcltk_sources = ["Src/X11/events_tcltk.c",
                           "libXt-1.2.1/src/Alloc.c",
                           "libXt-1.2.1/src/ArgList.c",
                           "libXt-1.2.1/src/Callback.c",
                           "libXt-1.2.1/src/Composite.c",
                           "libXt-1.2.1/src/Constraint.c",
                           "libXt-1.2.1/src/Convert.c",
                           "libXt-1.2.1/src/Converters.c",
                           "libXt-1.2.1/src/Core.c",
                           "libXt-1.2.1/src/Create.c",
                           "libXt-1.2.1/src/Destroy.c",
                           "libXt-1.2.1/src/Display.c",
                           "libXt-1.2.1/src/Error.c",
                           "libXt-1.2.1/src/Event.c",
                           "libXt-1.2.1/src/EventUtil.c",
                           "libXt-1.2.1/src/GCManager.c",
                           "libXt-1.2.1/src/Geometry.c",
                           "libXt-1.2.1/src/GetResList.c",
                           "libXt-1.2.1/src/GetValues.c",
                           "libXt-1.2.1/src/HookObj.c",
                           "libXt-1.2.1/src/Hooks.c",
                           "libXt-1.2.1/src/Initialize.c",
                           "libXt-1.2.1/src/Intrinsic.c",
                           "libXt-1.2.1/src/Keyboard.c",
                           "libXt-1.2.1/src/Manage.c",
                           "libXt-1.2.1/src/NextEvent.c",
                           "libXt-1.2.1/src/Object.c",
                           "libXt-1.2.1/src/PassivGrab.c",
                           "libXt-1.2.1/src/Pointer.c",
                           "libXt-1.2.1/src/Popup.c",
                           "libXt-1.2.1/src/RectObj.c",
                           "libXt-1.2.1/src/ResConfig.c",
                           "libXt-1.2.1/src/Resources.c",
                           "libXt-1.2.1/src/Selection.c",
                           "libXt-1.2.1/src/SetSens.c",
                           "libXt-1.2.1/src/SetValues.c",
                           "libXt-1.2.1/src/Shell.c",
                           "libXt-1.2.1/src/StringDefs.c",
                           "libXt-1.2.1/src/TMaction.c",
                           "libXt-1.2.1/src/TMgrab.c",
                           "libXt-1.2.1/src/TMkey.c",
                           "libXt-1.2.1/src/TMparse.c",
                           "libXt-1.2.1/src/TMprint.c",
                           "libXt-1.2.1/src/TMstate.c",
                           "libXt-1.2.1/src/Varargs.c",
                           "libXt-1.2.1/src/VarCreate.c",
                           "libXt-1.2.1/src/Vendor.c",
                          ]
    gui_sources = ["Src/X11/window.c",
                   "Src/X11/graphics.c",
                   "Src/X11/gui.c",
                  ]
    include_dirs.append("/opt/X11/include")
    extra_link_args = ["-L/opt/X11/lib/", "-lX11"]

extension = Extension("guitk.events",
                      event_sources,
                      include_dirs=include_dirs,
                      extra_link_args=extra_link_args,
                      )

extensions.append(extension)

extension = Extension("guitk.events_tcltk",
                      event_tcltk_sources,
                      include_dirs=include_dirs+["/usr/include/tcl8.6/tcl-private/generic/", "/usr/include/tcl8.6/tcl-private/unix/", "/usr/include/tcl8.6/tk-private/generic/", "/usr/include/tcl8.6/tk-private/unix/", "libXt-1.2.1/include/X11/", "/usr/include/X11"],
                      extra_link_args=extra_link_args + ["-ltcl8.6", "/usr/lib/python3.12/lib-dynload/_tkinter.cpython-312-x86_64-linux-gnu.so", "-lICE", "-lSM"],
                      )

extensions.append(extension)

extension = Extension("guitk.gui",
                      gui_sources,
                      include_dirs=include_dirs,
                      extra_link_args=extra_link_args,
                      )

extensions.append(extension)

setup(
      name = "guitk",
      version = "0.0.0",
      packages = ['guitk'],
      ext_modules=extensions,
      )
