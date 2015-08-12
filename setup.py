#!/usr/bin/env python

from distutils.core import setup, Extension, Command
import sys
import os.path
import sys
import numpy

sources = ["Src/Mac/_guitk.m",
           "Src/Mac/window.m",
           "Src/Mac/label.m",
          ]

extension = Extension("_guitk",
                      sources,
                      include_dirs=['Src'],
                      )

extension.extra_link_args.extend(['-framework', 'Cocoa'])

setup(
      ext_modules=[extension],
      )
