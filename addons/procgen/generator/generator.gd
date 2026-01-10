extends Node

signal finished

const Context = preload("context.gd")
const BSP = preload("bsp.gd")

var ctx: Context
var bsp: BSP

func generate(ctx: Context):
	self.ctx = ctx
	bsp = BSP.new(ctx)
	bsp.generate()
	finished.emit()
