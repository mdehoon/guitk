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
                      include_dirs=include_dirs+["/usr/include/tcl8.6/tcl-private/generic/", "/usr/include/tcl8.6/tcl-private/unix/", "/usr/include/tcl8.6/tk-private/generic/", "/usr/include/tcl8.6/tk-private/unix/"],
                      extra_link_args=extra_link_args + ["-lXt", "-ltcl8.6"],
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
