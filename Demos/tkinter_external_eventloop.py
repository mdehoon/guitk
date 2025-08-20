import tkinter
from guitk import events_tcltk

window = tkinter.Tk()

label = tkinter.Label(window, text="Tkinter", font='Helvetica 40', width=40)
label.pack()

def clicked():
    print("***************************************** Tkinter button clicked!!")

button = tkinter.Button(window, text="Click me", command=clicked, font='Helvetica 20', width=40)
button.pack()

events_tcltk.simple()
events_tcltk.start()
