import guitk

def say_hi():
    print "hi there, everyone"

window = guitk.Window(300,100, 'Hello')
# button = guitk._guitk.Button(text="Hello", command=say_hi)
button = guitk._guitk.Button("Hello")
window.add(button)
window.pack()
window.show()

