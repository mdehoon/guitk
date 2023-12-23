# Original Tkinter version is available here:
# http://effbot.org/tkinterbook/tkinter-hello-tkinter.htm

from guitk import gui

window = gui.Window()
label = gui.Label("Hello, world \U0001f30e!")
window.content = label
window.size = label.minimum_size
window.show()
