extends Node

signal finished

const Context = preload("context.gd")
const Bsp = preload("bsp.gd")

var ctx: Context

func generate(ctx: Context):
	self.ctx = ctx
	var bsp := Bsp.new(ctx)
	bsp.generate()
	finished.emit()
