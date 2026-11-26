class_name D
# Toutes les données fixes du jeu (cartes, monstres, donjons, talents, reliques, familiers, succès).

const MONSTERS := {
	"zombie": {"name": "Zombie", "sprite": "zombie", "scale": 0.95},
	"squelette": {"name": "Squelette", "sprite": "squelette", "scale": 0.95},
	"fantome": {"name": "Fantôme", "sprite": "fantome", "scale": 0.95},
	"vampire": {"name": "Vampire", "sprite": "vampire", "scale": 1.0},
	"gardien": {"name": "Fossoyeur", "sprite": "gardien", "scale": 1.0},
	"orc": {"name": "Orc", "sprite": "orc", "scale": 1.05},
	"sq_minion": {"name": "Larbin d'os", "sprite": "sq_minion", "scale": 1.0},
	"sq_guerrier": {"name": "Guerrier d'os", "sprite": "sq_guerrier", "scale": 1.05},
	"sq_voleur": {"name": "Rôdeur d'os", "sprite": "sq_voleur", "scale": 1.05},
	"sq_mage": {"name": "Nécromancien", "sprite": "sq_mage", "scale": 1.05},
	"brute": {"name": "Brute de lave", "sprite": "brute", "scale": 1.2},
	"rodeur": {"name": "Traqueur aveugle", "sprite": "rodeur", "scale": 1.1},
	"dragon": {"name": "Dragon ancien", "sprite": "dragon", "scale": 1.3},
}

# 10 thèmes de cartes ; après la carte 10, les thèmes reviennent en « Cauchemar ».
const MAPS := [
	{"name": "Prairie des Débuts", "mobs": ["zombie", "squelette", "sq_minion"], "boss": "gardien", "sky": [Color("6fb6e8"), Color("cfeaf7")], "ground": Color("5f9e45"), "hill": Color("4b8237"), "tint": Color(1, 1, 1)},
	{"name": "Cimetière Brumeux", "mobs": ["fantome", "zombie", "squelette"], "boss": "vampire", "sky": [Color("3c4a63"), Color("8a97ad")], "ground": Color("4a5446"), "hill": Color("39413a"), "tint": Color(0.9, 0.95, 1.05)},
	{"name": "Cryptes Oubliées", "mobs": ["sq_minion", "sq_voleur", "sq_guerrier"], "boss": "sq_mage", "sky": [Color("2a2233"), Color("5b4a63")], "ground": Color("5a5058"), "hill": Color("443c45"), "tint": Color(1, 0.95, 1.05)},
	{"name": "Camp des Orcs", "mobs": ["orc", "sq_guerrier", "zombie"], "boss": "brute", "sky": [Color("d98a4e"), Color("f4d28f")], "ground": Color("9b7442"), "hill": Color("7d5a32"), "tint": Color(1.05, 1.0, 0.92)},
	{"name": "Forêt des Murmures", "mobs": ["rodeur", "fantome", "orc"], "boss": "rodeur", "sky": [Color("203a2c"), Color("4f7a57")], "ground": Color("2f5230"), "hill": Color("243f25"), "tint": Color(0.9, 1.05, 0.9)},
	{"name": "Marais Putride", "mobs": ["zombie", "rodeur", "sq_voleur"], "boss": "vampire", "sky": [Color("4a5a2a"), Color("9aa860")], "ground": Color("55602e"), "hill": Color("434c22"), "tint": Color(0.85, 1.05, 0.75)},
	{"name": "Pics Gelés", "mobs": ["sq_guerrier", "fantome", "orc"], "boss": "brute", "sky": [Color("8fc3e8"), Color("eef7ff")], "ground": Color("d6e6f0"), "hill": Color("b4cddd"), "tint": Color(0.8, 0.9, 1.25)},
	{"name": "Désert de Cendres", "mobs": ["brute", "sq_mage", "orc"], "boss": "dragon", "sky": [Color("6b2f1d"), Color("d0743c")], "ground": Color("7a4a2a"), "hill": Color("5c341c"), "tint": Color(1.15, 0.9, 0.8)},
	{"name": "Citadelle Vampire", "mobs": ["vampire", "sq_mage", "rodeur"], "boss": "vampire", "sky": [Color("3a0f1f"), Color("8c2b45")], "ground": Color("3d2630"), "hill": Color("2c1a22"), "tint": Color(1.1, 0.85, 0.9)},
	{"name": "Gouffre d'Abyssia", "mobs": ["brute", "rodeur", "sq_guerrier"], "boss": "dragon", "sky": [Color("0d0a1f"), Color("3b2a6b")], "ground": Color("261d40"), "hill": Color("1a1430"), "tint": Color(0.85, 0.8, 1.2)},
]

const RARITY_NAMES := ["Commun", "Peu commun", "Rare", "Épique", "Légendaire", "Mythique"]
const RARITY_COLORS := [Color("c8c8c8"), Color("6ee06e"), Color("4fa8ff"), Color("c06cff"), Color("ffb03a"), Color("ff4f6e")]
const RARITY_MULT := [1.0, 1.6, 2.5, 4.0, 6.5, 11.0]
const RARITY_WEIGHTS := [600.0, 260.0, 100.0, 32.0, 7.0, 1.0]

const SLOTS := ["arme", "casque", "armure", "gants", "bottes", "anneau", "amulette"]
const SLOT_NAMES := {"arme": "Arme", "casque": "Casque", "armure": "Armure", "gants": "Gants", "bottes": "Bottes", "anneau": "Anneau", "amulette": "Amulette"}
# Stat principale de chaque emplacement.
const SLOT_MAIN := {"arme": "dmg", "casque": "hp", "armure": "def", "gants": "aps", "bottes": "gold", "anneau": "critd", "amulette": "dmg"}
const SLOT_ICONS := {
	"arme": ["013_sword_1handed", "014_sword_2handed", "000_axe_1handed", "001_axe_2handed", "052_staff", "047_dagger", "015_sword_2handed_color", "058_Skeleton_Blade", "061_Skeleton_Staff"],
	"casque": ["003_shield_badge_color"], "armure": ["010_shield_square_color", "004_shield_round", "008_shield_spikes_color"],
	"gants": ["041_hammer"], "bottes": ["050_quiver"], "anneau": ["062_Copper_Bar"], "amulette": ["011_spellbook_closed", "012_spellbook_open"],
}
const ITEM_PREFIX := ["Usé", "Solide", "Raffiné", "Héroïque", "Légendaire", "Mythique"]
const ITEM_BASE := {"arme": ["Épée", "Hache", "Lame", "Bâton", "Dague"], "casque": ["Heaume", "Casque", "Couronne"], "armure": ["Cuirasse", "Armure", "Plastron"], "gants": ["Gantelets", "Poings", "Mitaines"], "bottes": ["Bottes", "Grèves", "Sandales"], "anneau": ["Anneau", "Chevalière", "Bague"], "amulette": ["Amulette", "Talisman", "Grimoire"]}

# Stats secondaires possibles (en %).
const SUBS := {
	"dmg": {"name": "Dégâts", "base": 6.0},
	"aps": {"name": "Vitesse d'attaque", "base": 2.0},
	"crit": {"name": "Critique", "base": 0.8},
	"critd": {"name": "Dégâts critiques", "base": 6.0},
	"tap": {"name": "Dégâts de frappe", "base": 10.0},
	"gold": {"name": "Or", "base": 6.0},
	"xp": {"name": "Expérience", "base": 5.0},
	"boss": {"name": "Dégâts aux boss", "base": 8.0},
	"hp": {"name": "PV (arène)", "base": 6.0},
	"def": {"name": "Défense (arène)", "base": 1.5},
}

const CLASSES := {
	"chevalier": {"name": "Chevalier", "sprite": "h_chevalier", "desc": "+25 % PV et +10 % défense en arène, +10 % dégâts aux boss.", "hp": 0.25, "def": 10.0, "boss": 10.0},
	"barbare": {"name": "Barbare", "sprite": "h_barbare", "desc": "+20 % dégâts, +15 % dégâts de frappe.", "dmg": 20.0, "tap": 15.0},
	"mage": {"name": "Mage", "sprite": "h_mage", "desc": "+40 % dégâts critiques, +3 % critique.", "critd": 40.0, "crit": 3.0},
	"voleur": {"name": "Voleur", "sprite": "h_voleur", "desc": "+25 % or, +10 % vitesse, +5 % esquive en arène.", "gold": 25.0, "aps": 10.0, "dodge": 5.0},
}

# Entraînement (or) — réinitialisé à l'ascension.
const TRAIN := {
	"atk": {"name": "Puissance", "desc": "Dégâts +10 % (×2 tous les 10 niveaux)", "cost": 5.0, "grow": 1.09, "icon": "014_sword_2handed"},
	"tap": {"name": "Frappe", "desc": "Dégâts de frappe +6 %", "cost": 8.0, "grow": 1.09, "max": 400, "icon": "041_hammer"},
	"speed": {"name": "Célérité", "desc": "Vitesse d'attaque +2 %", "cost": 25.0, "grow": 1.11, "icon": "050_quiver", "max": 250},
	"crit": {"name": "Précision", "desc": "Critique +0,3 % et dégâts critiques +4 %", "cost": 40.0, "grow": 1.12, "icon": "047_dagger", "max": 150},
	"greed": {"name": "Avarice", "desc": "Or +8 %", "cost": 60.0, "grow": 1.1, "max": 150, "icon": "062_Copper_Bar"},
}

const SKILLS := [
	{"id": "frappe", "name": "Frappe céleste", "desc": "Inflige 40× tes dégâts.", "cd": 25.0, "dur": 0.0, "lvl": 3},
	{"id": "rage", "name": "Rage", "desc": "Dégâts ×3 pendant 12 s.", "cd": 70.0, "dur": 12.0, "lvl": 8},
	{"id": "hate", "name": "Hâte", "desc": "Vitesse ×2 pendant 12 s.", "cd": 70.0, "dur": 12.0, "lvl": 15},
	{"id": "pluie", "name": "Pluie d'or", "desc": "Or ×4 pendant 20 s.", "cd": 120.0, "dur": 20.0, "lvl": 25},
]

# Arbre de talents : 3 branches ; chaque talent exige le précédent de la branche au niveau 5.
const TALENTS := [
	{"id": "t_lame", "br": 0, "name": "Lame aiguisée", "desc": "+8 % dégâts / niv", "max": 25},
	{"id": "t_furie", "br": 0, "name": "Furie", "desc": "+3 % vitesse / niv", "max": 20},
	{"id": "t_brise", "br": 0, "name": "Brise-boss", "desc": "+10 % dégâts aux boss / niv", "max": 20},
	{"id": "t_rage", "br": 0, "name": "Rage durable", "desc": "+1 s de Rage et Hâte / niv", "max": 10},
	{"id": "t_titan", "br": 0, "name": "Titan", "desc": "Dégâts ×1,10 / niv (multiplicatif)", "max": 15},
	{"id": "t_oeil", "br": 1, "name": "Œil de faucon", "desc": "+0,5 % critique / niv", "max": 20},
	{"id": "t_mortel", "br": 1, "name": "Coup mortel", "desc": "+15 % dégâts critiques / niv", "max": 20},
	{"id": "t_doigt", "br": 1, "name": "Doigts agiles", "desc": "+20 % dégâts de frappe / niv", "max": 20},
	{"id": "t_echo", "br": 1, "name": "Écho céleste", "desc": "Frappe céleste +10× / niv", "max": 10},
	{"id": "t_auto", "br": 1, "name": "Main fantôme", "desc": "1 frappe auto / s par niv", "max": 10},
	{"id": "t_or", "br": 2, "name": "Chercheur d'or", "desc": "+10 % or / niv", "max": 25},
	{"id": "t_butin", "br": 2, "name": "Pilleur", "desc": "+5 % chance d'objet / niv", "max": 20},
	{"id": "t_temps", "br": 2, "name": "Maître du temps", "desc": "+1 s aux chronos / niv", "max": 15},
	{"id": "t_oeufs", "br": 2, "name": "Couveur", "desc": "+8 % chance d'œuf / niv", "max": 15},
	{"id": "t_veine", "br": 2, "name": "Veine de mithril", "desc": "+10 % minerai / niv", "max": 20},
]
const TALENT_BRANCHES := ["Guerrier", "Chasseur", "Fortune"]

# Reliques (âmes) — permanentes.
const RELICS := [
	{"id": "r_lame", "name": "Lame ancestrale", "desc": "Dégâts ×1,2 / niv", "cost": 1.0, "grow": 1.22, "max": 0},
	{"id": "r_bourse", "name": "Bourse éternelle", "desc": "Or ×1,18 / niv", "cost": 1.0, "grow": 1.25, "max": 0},
	{"id": "r_main", "name": "Main divine", "desc": "Frappe ×1,25 / niv", "cost": 2.0, "grow": 1.3, "max": 0},
	{"id": "r_sablier", "name": "Sablier", "desc": "+1 s aux boss / niv", "cost": 3.0, "grow": 1.6, "max": 20},
	{"id": "r_oeil", "name": "Œil du destin", "desc": "+1 % critique / niv", "cost": 2.0, "grow": 1.5, "max": 30},
	{"id": "r_savoir", "name": "Couronne du savoir", "desc": "XP ×1,2 / niv", "cost": 2.0, "grow": 1.35, "max": 0},
	{"id": "r_cle", "name": "Clé d'ombre", "desc": "+1 clé max et recharge +10 % / niv", "cost": 5.0, "grow": 1.8, "max": 10},
	{"id": "r_echo", "name": "Trésor du passé", "desc": "Chaque ascension démarre avec de l'or (plus à chaque niv)", "cost": 3.0, "grow": 1.5, "max": 25},
	{"id": "r_ame", "name": "Âme sœur", "desc": "Âmes +12 % / niv", "cost": 5.0, "grow": 1.45, "max": 0},
	{"id": "r_bete", "name": "Esprit bestial", "desc": "Familiers +12 % / niv", "cost": 4.0, "grow": 1.4, "max": 0},
]

# Donjons : salles de 5 à 20.
const DUNGEONS := [
	{"id": "d_crypte", "name": "Crypte des Os", "rooms": 5, "unlock": 8, "mobs": ["sq_minion", "squelette", "sq_voleur"], "boss": "sq_guerrier", "reward": "ore", "desc": "Récompense : beaucoup de minerai"},
	{"id": "d_nid", "name": "Nid du Dragon", "rooms": 8, "unlock": 18, "mobs": ["orc", "brute", "rodeur"], "boss": "dragon", "reward": "eggs", "desc": "Récompense : œufs de familiers"},
	{"id": "d_forge", "name": "Forge Infernale", "rooms": 10, "unlock": 28, "mobs": ["brute", "orc", "sq_guerrier"], "boss": "brute", "reward": "items", "desc": "Récompense : équipements rares"},
	{"id": "d_sanct", "name": "Sanctuaire Perdu", "rooms": 12, "unlock": 40, "mobs": ["fantome", "sq_mage", "vampire"], "boss": "sq_mage", "reward": "talent", "desc": "Récompense : points de talent"},
	{"id": "d_tresor", "name": "Salle des Trésors", "rooms": 15, "unlock": 55, "mobs": ["gardien", "vampire", "sq_voleur"], "boss": "vampire", "reward": "gems", "desc": "Récompense : gemmes et or"},
	{"id": "d_abime", "name": "Cœur de l'Abîme", "rooms": 20, "unlock": 75, "mobs": ["rodeur", "brute", "dragon"], "boss": "dragon", "reward": "souls", "desc": "Récompense : âmes et objets mythiques"},
]

# Familiers : 3 œufs, 4 espèces par œuf.
const EGGS := [
	{"id": "emeraude", "name": "Œuf d'émeraude", "icon": "DragonEgg_Emerald", "cost": 120},
	{"id": "feu", "name": "Œuf de feu", "icon": "DragonEgg_Fire", "cost": 200},
	{"id": "glace", "name": "Œuf de glace", "icon": "DragonEgg_Ice", "cost": 200},
]
const PETS := [
	{"name": "Gobelin vert", "egg": 0, "sprite": "zombie", "stat": "xp", "tint": Color(0.8, 1.2, 0.8)},
	{"name": "Feu follet", "egg": 0, "sprite": "fantome", "stat": "crit", "tint": Color(0.7, 1.3, 0.8)},
	{"name": "Petit os", "egg": 0, "sprite": "squelette", "stat": "aps", "tint": Color(0.9, 1.15, 0.9)},
	{"name": "Gardien moussu", "egg": 0, "sprite": "gardien", "stat": "def", "tint": Color(0.7, 1.2, 0.7)},
	{"name": "Dragonnet", "egg": 1, "sprite": "dragon", "stat": "dmg", "tint": Color(1.2, 0.8, 0.7)},
	{"name": "Diablotin", "egg": 1, "sprite": "orc", "stat": "tap", "tint": Color(1.3, 0.6, 0.6)},
	{"name": "Golem de braise", "egg": 1, "sprite": "brute", "stat": "boss", "tint": Color(1.2, 0.8, 0.6)},
	{"name": "Mage pyro", "egg": 1, "sprite": "sq_mage", "stat": "critd", "tint": Color(1.3, 0.8, 0.6)},
	{"name": "Spectre givré", "egg": 2, "sprite": "fantome", "stat": "gold", "tint": Color(0.7, 0.9, 1.4)},
	{"name": "Vampire des neiges", "egg": 2, "sprite": "vampire", "stat": "hp", "tint": Color(0.8, 0.9, 1.3)},
	{"name": "Traqueur polaire", "egg": 2, "sprite": "rodeur", "stat": "dmg", "tint": Color(0.8, 0.95, 1.35)},
	{"name": "Wyrm de cristal", "egg": 2, "sprite": "dragon", "stat": "gold", "tint": Color(0.7, 0.9, 1.5)},
]
# Valeur du bonus d'un familier (en %), par stat.
const PET_STAT_BASE := {"dmg": 10.0, "aps": 3.0, "crit": 1.0, "critd": 15.0, "tap": 15.0, "gold": 12.0, "xp": 12.0, "boss": 12.0, "hp": 10.0, "def": 2.0}

# Découvertes secrètes : description cachée tant qu'elles ne sont pas trouvées.
const SECRETS := [
	{"id": "s_frenesie", "name": "Frénésie", "hint": "Les doigts les plus rapides de l'ouest…", "how": "50 frappes en 10 secondes", "bonus": "+15 % dégâts de frappe", "stat": "tap", "val": 15.0},
	{"id": "s_pacifiste", "name": "Pacifiste", "hint": "Parfois, il suffit de regarder.", "how": "Vaincre un boss sans frapper", "bonus": "+10 % dégâts", "stat": "dmg", "val": 10.0},
	{"id": "s_dore", "name": "Chasseur doré", "hint": "Tout ce qui brille…", "how": "Vaincre 10 monstres dorés", "bonus": "+15 % or", "stat": "gold", "val": 15.0},
	{"id": "s_nuit", "name": "Insomniaque", "hint": "Les monstres rôdent quand tout dort.", "how": "Jouer entre 2 h et 5 h du matin", "bonus": "+10 % XP", "stat": "xp", "val": 10.0},
	{"id": "s_maudit", "name": "Forgeron maudit", "hint": "L'échec est un maître.", "how": "Rater 10 améliorations", "bonus": "+5 % réussite à la forge", "stat": "forge", "val": 5.0},
	{"id": "s_nostalgie", "name": "Nostalgique", "hint": "Retourner aux sources…", "how": "Tuer 100 monstres en Prairie après avoir atteint la carte 5", "bonus": "+10 % dégâts", "stat": "dmg", "val": 10.0},
	{"id": "s_trio", "name": "Éleveur", "hint": "Émeraude, feu et glace.", "how": "Posséder un familier de chaque œuf", "bonus": "+15 % familiers", "stat": "pet", "val": 15.0},
	{"id": "s_mythe", "name": "Légende vivante", "hint": "Une couleur rouge sang…", "how": "Obtenir un objet mythique", "bonus": "+20 % dégâts", "stat": "dmg", "val": 20.0},
	{"id": "s_eclair", "name": "Éclair", "hint": "La vitesse après la renaissance.", "how": "Atteindre l'étape 30 moins de 10 min après une ascension", "bonus": "+15 % âmes", "stat": "souls", "val": 15.0},
	{"id": "s_nom", "name": "Le Vrai Nom", "hint": "Un nom résonne dans le gouffre.", "how": "Se renommer « Abyssia »", "bonus": "+300 gemmes", "stat": "", "val": 0.0},
	{"id": "s_tetu", "name": "Têtu", "hint": "Échouer encore et encore…", "how": "Échouer 25 fois contre un boss", "bonus": "+3 s aux chronos", "stat": "time", "val": 3.0},
	{"id": "s_millier", "name": "Mille coups", "hint": "Un critique, puis un autre…", "how": "Réussir 10 critiques d'affilée", "bonus": "+25 % dégâts critiques", "stat": "critd", "val": 25.0},
	{"id": "s_abime", "name": "Regard de l'abîme", "hint": "Descendre, toujours plus bas.", "how": "Atteindre l'étage 50 de l'Abysse", "bonus": "+10 % dégâts aux boss", "stat": "boss", "val": 10.0},
	{"id": "s_riche", "name": "Crésus", "hint": "Avoir plus d'or qu'un roi.", "how": "Posséder 1 milliard d'or", "bonus": "+10 % or", "stat": "gold", "val": 10.0},
]

const BESTIARY_TIERS := [100, 1000, 10000, 100000, 1000000]

# Quêtes du jour.
const QUESTS := [
	{"id": "q_kill", "name": "Tuer %d monstres", "base": 300, "stat": "kills", "gems": 25},
	{"id": "q_boss", "name": "Vaincre %d boss", "base": 5, "stat": "bosses", "gems": 30},
	{"id": "q_tap", "name": "Frapper %d fois", "base": 800, "stat": "taps", "gems": 20},
	{"id": "q_dj", "name": "Terminer %d donjons", "base": 2, "stat": "dungeons", "gems": 40},
	{"id": "q_pvp", "name": "Combattre %d fois dans l'arène", "base": 3, "stat": "pvp", "gems": 35},
	{"id": "q_forge", "name": "Améliorer %d fois un objet", "base": 5, "stat": "forges", "gems": 25},
	{"id": "q_train", "name": "Acheter %d niveaux d'entraînement", "base": 50, "stat": "trains", "gems": 20},
	{"id": "q_abysse", "name": "Tenter %d fois l'Abysse", "base": 2, "stat": "abyss", "gems": 30},
	{"id": "q_skill", "name": "Utiliser %d compétences", "base": 15, "stat": "skills", "gems": 20},
]

const SHOP := [
	{"id": "egg0", "name": "Œuf d'émeraude", "gems": 120, "desc": "Un familier de la famille émeraude"},
	{"id": "egg1", "name": "Œuf de feu", "gems": 200, "desc": "Familier offensif"},
	{"id": "egg2", "name": "Œuf de glace", "gems": 200, "desc": "Familier de fortune"},
	{"id": "keys", "name": "3 clés de donjon", "gems": 60, "desc": "Pour entrer dans les donjons"},
	{"id": "ore", "name": "Sac de minerai", "gems": 50, "desc": "Minerai pour la forge"},
	{"id": "tickets", "name": "5 tickets d'arène", "gems": 50, "desc": "Combats PvP supplémentaires"},
	{"id": "boost_gold", "name": "Or ×2 (30 min)", "gems": 80, "desc": "Double l'or gagné"},
	{"id": "boost_dmg", "name": "Dégâts ×2 (30 min)", "gems": 80, "desc": "Double tes dégâts"},
	{"id": "talent", "name": "Point de talent", "gems": 250, "desc": "Un point de talent en plus"},
]

const HONOR := [
	{"id": "h_atk", "name": "Lame d'honneur", "desc": "+5 % attaque en arène / niv", "cost": 30.0, "grow": 1.25},
	{"id": "h_hp", "name": "Cœur d'honneur", "desc": "+5 % PV en arène / niv", "cost": 30.0, "grow": 1.25},
	{"id": "h_gems", "name": "Tribut", "desc": "+1 gemme par victoire en arène / niv", "cost": 60.0, "grow": 1.4},
]
