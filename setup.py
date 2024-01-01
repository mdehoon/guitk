#!/usr/bin/env python

import os.path
import sys

try:
    from setuptools import setup
    from setuptools import Command
    from setuptools import Extension
except ImportError:
    sys.exit(
        "We need the Python library setuptools to be installed. "
        "Try running: python -m ensurepip"
    )

extensions = []

sources = ["Src/Mac/events.m",
          ]

extension = Extension("guitk.events",
                      sources,
                      include_dirs=['Src','Src/Generic'],
                      )

extension.extra_link_args.extend(['-framework', 'Cocoa'])

extensions.append(extension)

sources = ["Src/Mac/gui.m",
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
          ]

extension = Extension("guitk.gui",
                      sources,
                      include_dirs=['Src','Src/Generic'],
                      )

extension.extra_link_args.extend(['-framework', 'Cocoa'])

extensions.append(extension)

setup(
      name = "guitk",
      packages = ['guitk'],
      package_dir = {'': 'Lib'},
      ext_modules=extensions,
      )
