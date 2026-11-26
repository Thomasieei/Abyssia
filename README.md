# Abyssia

Jeu mobile (Godot 4.7, Android, mode paysage) dans l'esprit d'Albion Online : vue du dessus, sorts donnés par l'équipement, récolte, camps de monstres, zones de danger.

**Étape 1 — prototype jouable** : la Clairière de Brumefeuille, posée à la main.
- Héros à l'épée large : attaque assistée (cible devant soi), 3 sorts d'arme (Entaille, Charge, Fracas) + 1 sort de plastron (Garde).
- Camp des brutes de lave (nord) et tanière des rôdeurs aveugles (est), IA LimboAI (machine à états : garde, alerte, poursuite, attaque annoncée au sol, retour au camp, fuite, étourdissement).
- Récolte du lin sauvage (prairie ouest).
- Ressenti des coups : micro-gel, flash, recul, secousse, sons, chiffres.

Dossiers :
- `game/` : projet Godot. `game/addons/limboai` : LimboAI 1.8.1 (MIT).
- `tools/extract_anims.gd` : extrait les animations utiles de la Universal Animation Library (Quaternius, CC0) vers `game/assets/anims/hero_anims.res`.
- `tools/net_supabase_legacy.gd` : ancienne connexion Supabase, gardée pour le marché et les classements.

Tests : `ABY_TEST=proto` joue une partie et enregistre des captures dans `/tmp/shots`. L'APK est construit par GitHub Actions et publié dans la release `apk`.

Crédits : Quaternius (personnages, animations, nature, village — CC0), Kenney (sons, particules — CC0), LimboAI (MIT).
