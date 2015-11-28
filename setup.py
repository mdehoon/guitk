#!/usr/bin/env python

from distutils.core import setup, Extension, Command
import sys
import os.path
import sys
import numpy

sources = ["Src/Mac/_guitk.m",
           "Src/Mac/window.m",
           "Src/Mac/grid.m",
           "Src/Mac/label.m",
           "Src/Mac/button.m",
           "Src/Generic/packed.c",
          ]

extension = Extension("guitk._guitk",
                      sources,
                      include_dirs=['Src','Src/Generic'],
                      )

extension.extra_link_args.extend(['-framework', 'Cocoa'])

setup(
      packages = ['guitk'],
      package_dir = {'': 'Lib'},
      ext_modules=[extension],
      )
