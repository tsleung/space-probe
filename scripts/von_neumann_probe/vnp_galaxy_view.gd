extends Control

## Custom drawing control for the galaxy map
## Delegates actual drawing to parent vnp_main.gd

func _draw():
	var parent = get_parent().get_parent().get_parent()  # GalaxyView -> GalaxyPanel -> MainContent -> VNP_Main
	if parent.has_method("draw_galaxy_on"):
		parent.draw_galaxy_on(self)
