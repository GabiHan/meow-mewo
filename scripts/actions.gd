# What you can do with each kind of furniture (Sims-style per-object interactions). Static.
# Clicking an object shows its actions (controller.gd); NPCs score every action of every object they
# may use (npc.gd choose_action) and pick the best, like any other option.
# Kitchen objects (Fridge, Stove, Counter, Sink, Table) keep their own menus (kitchen.gd).
#
# Each action: name (menu), verb (shown while doing it), minutes, ads {need: gain over the action},
# optional skill (practised), moodlet (when done), asleep (they're asleep: notice nothing; a Bed
# "Sleep" is the night's sleep that NPCs prefer at night).
# Objects without an entry here get one action from their own advertisements/duration ("Use").
const ACTIONS := {
	"Bed": [
		{"name": "Sleep", "verb": "Sleeping", "minutes": 420.0, "ads": {"energy": 100}, "moodlet": "Well rested", "asleep": true, "night": true},
		{"name": "Nap", "verb": "Napping", "minutes": 90.0, "ads": {"energy": 35}, "asleep": true},
		{"name": "Relax in bed", "verb": "Relaxing in bed", "minutes": 30.0, "ads": {"fun": 15, "energy": 5}},
	],
	"Crib": [
		{"name": "Sleep", "verb": "Sleeping", "minutes": 300.0, "ads": {"energy": 100}, "moodlet": "Well rested", "asleep": true, "night": true},
	],
	"Couch": [
		{"name": "Relax", "verb": "Relaxing", "minutes": 30.0, "ads": {"fun": 20, "energy": 10}},
		{"name": "Sit", "verb": "Sitting on the couch", "minutes": 15.0, "ads": {"energy": 5, "fun": 5}},
		{"name": "Nap on the couch", "verb": "Napping on the couch", "minutes": 60.0, "ads": {"energy": 30}, "asleep": true},
	],
	"Chair": [
		{"name": "Sit", "verb": "Sitting", "minutes": 10.0, "ads": {"energy": 5}},
	],
	"Toilet": [
		{"name": "Pee", "verb": "Peeing", "minutes": 2.0, "ads": {"bladder": 70}},
		{"name": "Poo", "verb": "Pooping", "minutes": 8.0, "ads": {"bladder": 80, "hygiene": -5}},
	],
	"Shower": [
		{"name": "Take a shower", "verb": "Showering", "minutes": 10.0, "ads": {"hygiene": 80}, "moodlet": "Freshened up"},
		{"name": "Take a bath", "verb": "Bathing", "minutes": 30.0, "ads": {"hygiene": 100, "fun": 15}, "moodlet": "Freshened up"},
	],
	"Bathroom sink": [
		{"name": "Wash hands", "verb": "Washing hands", "minutes": 2.0, "ads": {"hygiene": 10}},
		{"name": "Brush teeth", "verb": "Brushing teeth", "minutes": 3.0, "ads": {"hygiene": 15}},
	],
	"TV": [
		{"name": "Watch comedy", "verb": "Watching comedy", "minutes": 30.0, "ads": {"fun": 60}, "skill": "Comedy"},
		{"name": "Watch the news", "verb": "Watching the news", "minutes": 20.0, "ads": {"fun": 20}, "skill": "Logic"},
		{"name": "Watch a cooking show", "verb": "Watching a cooking show", "minutes": 30.0, "ads": {"fun": 35}, "skill": "Cooking"},
	],
	"Bookshelf": [
		{"name": "Read a textbook", "verb": "Reading", "minutes": 45.0, "ads": {"fun": 25}, "skill": "Logic", "moodlet": "Learned something"},
		{"name": "Read a novel", "verb": "Reading a novel", "minutes": 60.0, "ads": {"fun": 45}},
		{"name": "Read a cookbook", "verb": "Reading a cookbook", "minutes": 30.0, "ads": {"fun": 15}, "skill": "Cooking"},
		{"name": "Read a medical journal", "verb": "Reading a medical journal", "minutes": 40.0, "ads": {"fun": 10}, "skill": "Medicine", "moodlet": "Learned something"},
	],
	"Fireplace": [
		{"name": "Relax by the fire", "verb": "Relaxing by the fire", "minutes": 30.0, "ads": {"fun": 25, "social": 5}},
		{"name": "Warm up", "verb": "Warming up", "minutes": 15.0, "ads": {"energy": 10, "fun": 10}},
	],
	"Bench": [
		{"name": "Sit on the bench", "verb": "Sitting on the bench", "minutes": 15.0, "ads": {"fun": 25}},
	],
	"Nightstand": [
		{"name": "Write in a diary", "verb": "Writing in a diary", "minutes": 20.0, "ads": {"fun": 15}, "skill": "Creativity"},
		{"name": "Put on hand cream", "verb": "Putting on hand cream", "minutes": 2.0, "ads": {"hygiene": 5}},
	],
	"Coffee table": [
		{"name": "Do a jigsaw puzzle", "verb": "Doing a jigsaw puzzle", "minutes": 40.0, "ads": {"fun": 30}, "skill": "Logic"},
		{"name": "Put your feet up", "verb": "Putting their feet up", "minutes": 15.0, "ads": {"energy": 5, "fun": 10}},
	],
	"Desk": [
		{"name": "Study", "verb": "Studying", "minutes": 45.0, "ads": {"fun": 5}, "skill": "Logic", "moodlet": "Learned something"},
		{"name": "Write jokes", "verb": "Writing jokes", "minutes": 30.0, "ads": {"fun": 15}, "skill": "Comedy"},
		{"name": "Sketch designs", "verb": "Sketching designs", "minutes": 30.0, "ads": {"fun": 20}, "skill": "Creativity"},
		{"name": "Tinker with a gadget", "verb": "Tinkering with a gadget", "minutes": 30.0, "ads": {"fun": 15}, "skill": "Handiness"},
		{"name": "Practise first aid", "verb": "Practising first aid", "minutes": 30.0, "ads": {"fun": 5}, "skill": "Medicine", "moodlet": "Learned something"},
	],
	"Kitchen cabinet": [
		{"name": "Grab a snack", "verb": "Snacking", "minutes": 3.0, "ads": {"hunger": 15}},
		{"name": "Tidy the cupboard", "verb": "Tidying the cupboard", "minutes": 10.0, "ads": {"fun": 5}},
	],
	"Kitchen drawers": [
		{"name": "Sort the cutlery", "verb": "Sorting the cutlery", "minutes": 10.0, "ads": {"fun": 5}},
		{"name": "Read a recipe card", "verb": "Reading a recipe card", "minutes": 10.0, "ads": {"fun": 5}, "skill": "Cooking"},
	],
	"Lamp": [
		{"name": "Read under the lamp", "verb": "Reading under the lamp", "minutes": 30.0, "ads": {"fun": 20}, "skill": "Logic"},
	],
	"Plant": [
		{"name": "Water the plant", "verb": "Watering the plant", "minutes": 3.0, "ads": {"fun": 8}},
		{"name": "Talk to the plant", "verb": "Talking to the plant", "minutes": 5.0, "ads": {"social": 5, "fun": 3}},
	],
	"Rug": [
		{"name": "Do yoga", "verb": "Doing yoga", "minutes": 20.0, "ads": {"fun": 10, "energy": -5}, "skill": "Fitness"},
		{"name": "Stretch", "verb": "Stretching", "minutes": 5.0, "ads": {"energy": 3}},
	],
	"Shelf": [
		{"name": "Browse the shelf", "verb": "Browsing the shelf", "minutes": 10.0, "ads": {"fun": 10}},
		{"name": "Dust the shelf", "verb": "Dusting the shelf", "minutes": 5.0, "ads": {"hygiene": 3}},
	],
	"Dresser": [
		{"name": "Change clothes", "verb": "Changing clothes", "minutes": 5.0, "ads": {"hygiene": 15}},
		{"name": "Try on outfits", "verb": "Trying on outfits", "minutes": 20.0, "ads": {"fun": 20}},
	],
	"Phone": [
		{"name": "Call a friend", "verb": "On the phone", "minutes": 15.0, "ads": {"social": 25, "fun": 5}, "skill": "Charisma"},
	],
	"Alarm": [
		{"name": "Test the alarm", "verb": "Testing the alarm", "minutes": 2.0, "ads": {"fun": 1}},
	],
	"Guitar": [
		{"name": "Play the guitar", "verb": "Playing the guitar", "minutes": 30.0, "ads": {"fun": 40}, "skill": "Creativity"},
		{"name": "Write a song", "verb": "Writing a song", "minutes": 40.0, "ads": {"fun": 25}, "skill": "Creativity", "moodlet": "Learned something"},
	],
	"Toy": [
		{"name": "Play with the toy car", "verb": "Playing with the toy car", "minutes": 15.0, "ads": {"fun": 30}},
	],
	"Exercise bike": [
		{"name": "Ride the exercise bike", "verb": "Riding the exercise bike", "minutes": 30.0, "ads": {"fun": 15, "energy": -10, "hygiene": -10}, "skill": "Fitness", "moodlet": "Pumped"},
		{"name": "Tune up the bike", "verb": "Tuning up the bike", "minutes": 20.0, "ads": {"fun": 8}, "skill": "Handiness"},
	],
	"Game console": [
		{"name": "Play video games", "verb": "Playing video games", "minutes": 40.0, "ads": {"fun": 55, "energy": -3}},
		{"name": "Play a puzzle game", "verb": "Playing a puzzle game", "minutes": 30.0, "ads": {"fun": 35}, "skill": "Logic"},
	],
	"Grandfather clock": [
		{"name": "Wind the clock", "verb": "Winding the clock", "minutes": 3.0, "ads": {"fun": 5}},
		{"name": "Oil the clock's gears", "verb": "Oiling the clock's gears", "minutes": 20.0, "ads": {"fun": 8}, "skill": "Handiness"},
	],
	"Pull-up bar": [
		{"name": "Work out", "verb": "Working out", "minutes": 30.0, "ads": {"fun": 15, "energy": -10, "hygiene": -10}, "skill": "Fitness", "moodlet": "Pumped"},
		{"name": "Do a few pull-ups", "verb": "Doing pull-ups", "minutes": 10.0, "ads": {"fun": 8, "energy": -3}, "skill": "Fitness"},
	],
}

# Seats: you sit on the object itself (its tile stays walkable) instead of standing in front of it.
const SEATS := ["Couch", "Chair"]
# Used standing on the object itself (its tile stays walkable, drawn flat under people): rugs.
const STAND_ON := ["Rug"]


static func for_object(obj: Node2D) -> Array:
	if ACTIONS.has(obj.object_name):
		return ACTIONS[obj.object_name]
	var verb: String = obj.verb if obj.verb != "" else "Using " + obj.object_name
	var one := {"name": "Use", "verb": verb, "minutes": obj.duration, "ads": obj.advertisements}
	if obj.skill != "":
		one.skill = obj.skill
	if obj.moodlet != "":
		one.moodlet = obj.moodlet
	return [one]
