extends RefCounted
const T = preload("res://scripts/tuning.gd")
## Authored lane paths. These fixed arrays are the complete level; no generation RNG.
const SECTIONS: Array[String] = ["I   /   THE FIRST BREATH", "II   /   BROKEN VERSES", "III   /   THE WIND'S TEETH", "IV   /   HOUSE OF PAPER", "V   /   THE LAST THREAD"]
const SUBTITLES: Array[String] = ["Let the danger come to you.", "Trust the shape of the next opening.", "Lean against the wind. Keep the rhythm.", "Different hands. The same heartbeat.", "One more breath. Then another."]
const LANES: Array = [
 [540,540,570,610,640,610,560,520,470,430,460,510,560,600,550,510,470,510,550,600,640,600,550,510,460,500,540,570,540,540],
 [540,590,640,690,630,580,530,480,430,380,440,500,550,600,650,600,550,500,450,400,450,500,560,610,670,610,550,500,540,540],
 [540,600,660,710,640,570,500,430,370,430,490,550,620,680,620,550,480,410,350,420,490,560,630,700,630,560,490,430,490,540],
 [540,480,420,360,420,490,560,630,690,630,560,490,420,480,550,620,680,610,540,470,400,460,530,600,660,600,540,480,520,540],
 [540,600,670,610,540,470,400,470,540,610,680,610,540,470,400,460,520,580,640,700,630,560,490,420,480,540,600,560,540,540]
]
const PATTERNS: Array = [
 [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
 [1,1,1,1,1,0,0,1,0,1,0,1,0,0,1,1,0,1,0,0,1,0,1,0,1,0,1,0,0,0],
 [3,3,3,3,3,0,0,3,0,3,0,3,1,0,3,1,0,3,0,3,0,1,3,0,3,1,0,3,0,0],
 [2,2,2,2,2,0,1,2,3,0,2,1,3,2,0,1,2,3,1,0,3,2,0,1,2,3,0,2,1,0],
 [0,1,3,2,0,3,1,2,3,0,2,1,0,3,2,1,3,0,1,2,0,3,1,2,3,0,2,1,3,0]
]

static func build() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for section in range(5):
		for row in range(30):
			var index: int = section * 30 + row
			result.append({"pos": Vector2(LANES[section][row], -25.0 - index * T.ROW_HEIGHT), "type": (1 if row in [2, 16, 20, 24] else (2 if row in [18, 22, 26] else (3 if row in [21, 25, 28] else PATTERNS[section][row]))) if section == 0 else PATTERNS[section][row], "section": section, "index": index, "side": -1.0 if index % 2 == 0 else 1.0})
	return result
