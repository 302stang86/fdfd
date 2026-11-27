extends RefCounted

# Outfit, tint, personality, summary, role weights, flank bias, cover bias, reaction multiplier.
const PROFILES := [["Army fatigues","#63774b","Anchor","Deliberate and steady. Holds lanes and checks on allies.",[2,1,2,7,1],0,0.8,0.98],
	["Ninja","#34313d","Ghost","Patient and quiet. Takes the long route around cover.",[1,8,2,1,1],1.6,0.2,1],
	["Clown","#db4f64","Showboat","Bold and erratic. Pushes quickly and favors splash paint.",[4,2,1,1,7],0.1,-0.5,0.88],
	["Firefighter","#dcb05a","Rescuer","Protective and composed. Uses cover and sticks near teammates.",[2,1,1,8,1],0,1.1,1.06],
	["Police officer","#405a86","Marshal","Methodical and cautious. Watches routes and calls out sightings.",[1,1,4,7,1],-0.25,0.7,1.09],
	["Bunny cosplay","#e9b5cb","Decoy","Playful and restless. Repositions quickly and circles cover.",[4,7,1,1,2],0.85,0,0.9],
	["Robot","#9bb3ba","Precision","Calculating and patient. Favors longer lanes and measured shots.",[1,1,9,3,1],-0.45,0.45,1.15],
	["Emo","#543b64","Observer","Reserved and observant. Hangs back and finds side angles.",[1,5,6,2,1],0.55,0.5,1.1],
	["Patchwork Jester","#61415e","Trickster","Unpredictable. Flanks campers and uses splash paint to dislodge them.",[2,5,1,1,9],1.3,-0.3,0.94],
	["Trail Scout","#b48c57","Pathfinder","Curious and mobile. Investigates noise and looks for open routes.",[4,8,2,1,1],1.1,0.05,0.92],
	["Wraprunner","#cfb293","Survivor","Careful and elusive. Breaks contact quickly when pressured.",[1,6,2,3,1],0.8,1.35,1],
	["Revenant","#687766","Relentless","Stubborn and direct. Keeps pressing and rarely gives up ground.",[10,2,1,1,2],-0.4,-0.8,1.04],
	["Armored Sentinel","#666e79","Bulwark","Disciplined and defensive. Holds a lane and falls back to cover under pressure.",[2,1,3,9,2],-0.55,1.25,1.08]]

static func profile(skin: int) -> Array:
	return PROFILES[clampi(skin, 0, PROFILES.size() - 1)]

static func pick_role(skin: int) -> int:
	var weights: Array = profile(skin)[4]
	var total := 0
	for weight in weights:
		total += int(weight)
	var roll := randi_range(1, total)
	for index in range(weights.size()):
		roll -= int(weights[index])
		if roll <= 0:
			return index
	return 0
