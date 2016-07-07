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

sources = ["Src/Mac/_guitk.m",
           "Src/Mac/window.m",
           "Src/Mac/widgets.m",
           "Src/Mac/grid.m",
           "Src/Mac/label.m",
           "Src/Mac/button.m",
          ]

extension = Extension("guitk._guitk",
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
