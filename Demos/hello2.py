from guitk import gui

def say_hi():
    print "hi there, everyone"

window = gui.Window(300,100, 'Hello')
# button = guitk._guitk.Button(text="Hello", command=say_hi)
button = gui.Button("Hello")
window.add(button)
window.show()

