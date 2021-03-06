#!/usr/bin/env python

from distutils.core import setup, Extension, Command
import sys
import os.path
import sys

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
           "Src/Mac/frame.m",
           "Src/Mac/separator.m",
           "Src/Mac/label.m",
           "Src/Mac/button.m",
           "Src/Mac/checkbox.m",
           "Src/Mac/textbox.m",
           "Src/Mac/listbox.m",
           "Src/Generic/colors.c",
          ]

extension = Extension("guitk.gui",
                      sources,
                      include_dirs=['Src','Src/Generic'],
                      )

extension.extra_link_args.extend(['-framework', 'Cocoa'])

extensions.append(extension)

setup(
      packages = ['guitk'],
      package_dir = {'': 'Lib'},
      ext_modules=extensions,
      )
