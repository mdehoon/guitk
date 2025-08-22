import tkinter
from guitk import events_tcltk

window = tkinter.Tk()

label = tkinter.Label(window, text="Tkinter", font='Helvetica 40', width=15)
label.pack()

def clicked():
    print("Tkinter button clicked")

def update(counter=0):
    print("Tkinter timer update %d" % counter)
    window.after(1000, update, counter+1)

button1 = tkinter.Button(window, text="Click me", command=clicked, font='Helvetica 20', width=15)
button1.pack()

button2 = tkinter.Button(window, text="Start the timer", command=update, font='Helvetica 20', width=15)
button2.pack()


events_tcltk.simple()
events_tcltk.start()
