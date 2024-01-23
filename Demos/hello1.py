# Original Tkinter version is available here:
# http://effbot.org/tkinterbook/tkinter-hello-tkinter.htm

from guitk import gui

font = gui.Font("Helvetica", 40)

window = gui.Window()
label = gui.Label("Hello, world \U0001f30e!", font)
label.size = label.minimum_size
window.content = label
window.show()
