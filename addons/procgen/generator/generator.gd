extends Node

signal finished
signal automaton_iteration_finished

const Context = preload("context.gd")
const BSP = preload("bsp.gd")
const Automaton = preload("automaton.gd")
const Router = preload("router.gd")

var ctx: Context
var bsp: BSP = BSP.new()
var router: Router = Router.new()
var automaton: Automaton = Automaton.new()
var generating: bool = false


func _init():
	automaton.iteration_finished.connect(automaton_iteration_finished.emit)
	automaton.finished.connect(_on_automaton_finished)


func generate(ctx: Context):
	generating = true
	self.ctx = ctx
	bsp.generate(ctx)
	router.generate(ctx, bsp)
	automaton.generate(ctx, bsp, router)


func _on_automaton_finished():
	finished.emit()
	generating = false
