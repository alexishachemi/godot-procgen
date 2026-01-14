extends Node

signal finished

const Context = preload("context.gd")
const BSP = preload("bsp.gd")
const Automaton = preload("automaton.gd")
const Router = preload("router.gd")

var ctx: Context
var bsp: BSP
var router: Router
var automaton: Automaton
var corridor_segments: Array[Array]
var generating: bool = false

func generate(ctx: Context):
	generating = true
	self.ctx = ctx
	bsp = BSP.new(ctx)
	bsp.generate()
	router = Router.new(ctx)
	router.route_all_rooms(bsp)
	if ctx.automaton_iterations:
		automaton = Automaton.new(ctx)
		automaton.finished.connect(_on_automaton_finished, CONNECT_ONE_SHOT)
		automaton.generate()
	else:
		automaton = null
		finished.emit()
		generating = false

func _on_automaton_finished():
	finished.emit()
	generating = false
