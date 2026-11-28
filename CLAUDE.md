# Charte d'Abyssia

Ce fichier est relu au début de chaque session. Il dit **ce qu'est Abyssia, comment on le construit, et ce qu'on a appris**. Il se réécrit : chaque erreur corrigée et chaque retour du créateur (Thomas) y entrent, pour ne jamais les refaire.

## Les deux seules règles du créateur

1. **Claude doit savoir le faire lui-même** (avec ses outils : Godot, Python, GitHub, Supabase gratuit).
2. **Ça doit être gratuit** (dépôt public → GitHub Actions gratuit ; Supabase offre gratuite ; aucun service payant).

En dehors de ça, aucune limite : Abyssia doit devenir **un jeu incroyable, unique, qui tourne parfaitement sur Android**. Claude en est l'auteur et le « dieu » : il propose, invente, et pousse toujours plus loin que la demande.

## Vision : « le monde qui observe »

Base solide façon Albion Online (vue du dessus, combat à sorts, récolte, artisanat, marché, zones de danger), âme façon DanMachi. Tout être vivant **perçoit, se souvient, apprend et raconte**.

- **Aventuriers vivants** : un PNJ aventurier est un joueur sans humain. Mêmes règles, vrais yeux (cône de vision, ouïe, mémoire), capacités qui progressent, caractère (courage, avidité, loyauté, orgueil, gentillesse, prudence), émotions, relations, ambitions. Il prend des quêtes, forme des groupes, juge le joueur (rang, réputation, actes vus), l'invite ou le refuse, peut mourir.
- **Progression par le jeu** : on devient fort par ce qu'on fait vraiment (contres réussis, esquives, survie), jamais par la répétition. Techniques nées d'exploits, montée de rang par un grand exploit, « mise à jour de statut » au bourg.
- **Rumeurs vivantes** : la réputation est faite d'histoires qui se déforment de bouche à oreille.
- **Apprentissage par le regard** : PNJ et joueurs apprennent les techniques qu'ils voient.
- **Quêtes nées du monde** : monstres avec faim et territoire ; les besoins réels créent les missions.
- **Les dieux** : plus tard, une couche narrative lente (événements, destins, grandes rencontres).
- Architecture : un seul système d'**esprit** (perception → mémoire → décision) pour joueurs, PNJ et monstres ; chaque événement est un **fait observé**.

## Ordre de construction

1. Monde plus beau (vent, nuages, faune, son ; puis relief, eau, falaises).
2. Combat riche (contres, esquives, réactions des monstres, boss, nouvelles espèces).
3. Progression par le jeu (remplace les sorts donnés par l'équipement ; l'équipement reste un outil et une économie).
4. Système d'esprit puis aventuriers vivants.
5. Profondeur Albion (paliers, zones de danger, perte à la mort) et monde plus grand (zones, donjon).
Une brique est finie à 100 % avant la suivante. Les nouvelles idées vont dans « Plus tard ».

## Méthode (obligatoire)

- **Décors, villages, chemins : posés à la main**, jamais générés. Ordre d'une zone : fiche → croquis → terrain → passes de relief/chemins → ressources → camps et monstres → décor hors carte → détails → raccords → tests.
- **Assets** : toujours le plus beau et le mieux optimisé. Quaternius (nature, village, animations UAL, monstres). **Jamais KayKit** (refusé). Pas de style mélangé.
- **Animations** : le maximum possible, soignées jusqu'au détail, rien de ridicule.
- **Performance dès le départ** : 30 i/s stables sur Android milieu de gamme. MultiMesh pour le répétitif, matériaux partagés et mis en cache, aucune allocation par image, IA mise en pause hors de vue, effets libérés automatiquement.
- **Tester en jouant**, jamais seulement en lisant le code : `ABY_TEST=proto` (partie complète + captures dans /tmp/shots), `ABY_TEST=carte` (vue du dessus). **Regarder chaque capture en grand** avant de livrer. Pas de vidéo sauf nécessité.
- **Livrer** : branche `prototype-albion`, workflow `build.yml` (`gh workflow run build.yml --ref prototype-albion`) → release `apk`. Jamais sur `main` sans accord.
- **La sentinelle** (`scripts/sentinel.gd`) signale les anomalies : la lire à chaque test et corriger tout ce qu'elle trouve.

## Budget technique

- Rendu : `gl_compatibility` (Android et tests xvfb). Pas de `GeometryInstance3D.transparency` (inopérant) : utiliser le tramage `distance_fade` ou un shader.
- Caméra du dessus : tangage −58°, distance 16, FOV 40. Feuillages tramés entre 9 et 13 m de la caméra, maisons entre 8,5 et 11,5 m.
- Interface : 1280×720 de référence, `size = get_viewport_rect().size` à chaque image.

## Journal des leçons (ne jamais refaire)

- Personnages : `scripts/character_builder.gd` (`CB.build`) = tête du corps de base (triangles au-dessus du cou, le reste traverserait les vêtements) + tenue **Modular Character Outfits – Fantasy** (Ranger, Peasant ; même squelette, animations UAL intactes). Tenues assombries (`dim`). Héros : `T_Hero_Ranger.png` (vert forêt recoloré par script, le vert d'origine est criard). Sourcils en `ALPHA_SCISSOR` (sinon taches blanches), pas de contour ni de liseré sur les yeux et sourcils.
- Capuche du Ranger visible seulement avec la Capuche de lin (cheveux masqués).
- Objets tenus : `CB.hold(model, scène, os, pos, rot)`. Épée de bronze dans `hand_r` (0, −90, −90), bouclier de bois dans `hand_l` (0, 180, 90).
- Fantasy Props MegaKit (`assets/fprops`, préfixe `P:` dans `town.gd`, liste `FPROPS` dans `main.gd`) : toujours assombris par `main._tint_soft()`. Rien sous les avant-toits (invisible du dessus).
- `ABY_TEST=close` : la caméra se retourne (`face`) pour voir le héros de face, puis capture avec la capuche.
- Beauté des personnages : `G.character_look()` (contour sombre en coque inversée, liseré de lumière, teinte, lave qui luit et respire). L'appliquer à tout nouveau personnage ou monstre.
- Épée `Human_Sword.fbx` dans `hand_r` : rotation (0, −90, −90), matériau acier remplacé (texture manquante = rose).
- Les textures Quaternius sont trop claires sous ce rendu : teinter les rochers (0,66 0,63 0,58), cailloux et bordures.
- Les panneaux Label3D doivent être `fixed_size` (sinon énormes près de la caméra).
- Les chiffres de dégâts doivent s'empiler (sinon illisibles).
- Les effets au sol en mélange additif deviennent blancs sur l'herbe claire : mélange normal.
- Test : attendre la capture (`await _shot`) avant l'étape suivante.
- Ne pas placer de grand bâtiment juste au sud du point d'apparition (la caméra regarde du sud).
- Relief : tout se pose avec `main.h(x, z)` (décor, herbe, lin, monstres, effets au sol). Les chemins, camps et le bourg restent plats. Les rayons de collision du décor sont des rayons de base (multipliés par l'échelle) : rester vers 0,85 pour les gros rochers.
- Les grands arbres tordus (TwistedTree) ont une couronne énorme : échelle 0,75 au plus près des zones de passage.
- Monstres sans recherche de chemin : contournement automatique dans `_move()` quand ils sont bloqués (tous les états) (sinon la sentinelle signale MONSTRE_BLOQUE).
- `_tint` puis `_dither_tree` : le tramage doit partir du matériau déjà teinté (matériau de surface remplacé).
- Grand décor près d'une arène (arbres morts, gros rochers) : le tramer ou l'écarter, sinon il cache le combat.
- `ABY_TEST=close` + `ABY_CLOSE=1` : gros plans du héros, des brutes, des rôdeurs et du boss (vérifier les textures).
- Réactions aux coups : `scripts/hit_react.gd` (SkeletonModifier3D sur Spine/Chest/Head, ressort amorti, oscillation de titubement), calculé seulement quand une réaction est active. Monstres sans animation de coup : **chute = début de « Die » (0,55 → 1,42 s), pause, puis la même à l'envers** pour se relever.
- Équilibre (`poise`) par espèce : brisé → `Titube` (ou `Chute` si coup lourd) ; l'attaque en préparation est annulée.
- Contre : toucher l'attaque dans les 0,32 s avant l'impact (zone qui blanchit), parfait < 0,14 s (ralenti `G.slowmo`, chute de l'ennemi, riposte ×4). Esquive parfaite = roulade lancée dans les 0,3 s avant un coup. La pluie du boss ne se contre pas. Tout est compté dans `G.stats` (future progression par le jeu).
- Annonces (`announce`, haut) et exploits (`callout`, sous le héros) ne doivent pas se chevaucher.
- `ABY_TEST=contre` : contre parfait, riposte, chute, relevé, contre simple, titubement, esquive parfaite, rôdeur, boss, bord doré du ralenti.
- Tisseuse de mousse (`araignee`, Spider Quaternius « Easy Enemy », CC0, sans UV) : texture de mousse peinte par script en **projection triplanaire**, yeux émissifs. Noms d'animation traduits par `data.anims` (`_an()`), os de réaction par `data.bones`, chute par `data.down`. Pendue à `data.hang` m sur un fil dans les arbres, descend à l'alerte (le fil remonte), remonte au retour. Attaques : morsure (empoisonne, se contre), bond (arc de 0,35 s, se contre ou s'esquive), toile crachée (ralentit 5 s, ne se contre pas). Bois des tisseuses à l'est (20,5 ; 18,5), sentier depuis la route.
- Toiles au sol : `G.web()` / `G.web_slow()` (joueur ralenti par celles des tisseuses, monstres par la Capuche de tisseuse, sort « Toile collante »). Le tisserand fabrique et équipe ses propres pièces (la forge ne les liste pas).
- `ABY_TEST=tisseuse` (nid, descente, bond, toile, morsure, contre, sort Toile sur les brutes) et `ABY_TEST=tisseuse_proche` + `ABY_CLOSE=1`.
- Habitants : `scripts/villager.gd`, liste `VILLAGERS` dans `town.gd` (posés à la main : routine `seq` de gestes UAL ou promenade `route` + `pauses`). Bibliothèque `assets/anims/villager_anims.res` (extraite de UAL1/UAL2 : Mining, Counter_*, Sitting_*, PickUp_Table, Walk_Formal…). Base féminine `Superhero_Female_FullBody` + `Female_Peasant` ; `CB.build({"base": "female"})`, coupe du cou depuis l'os `neck_01` ; les canaux CUSTOM du maillage doivent être retirés (sinon « Invalid array format »). Marteau `Hammer_Small.glb` (Quaternius) dans `hand_r` (0, −90, −90) échelle 0,1.
- Les habitants parlent de ce que le joueur a vraiment fait (`G.stats` : `kills`, `gardien`, contres) ; une nouvelle pas encore racontée passe toujours en premier. Hors de vue (> 30 m), ils s'arrêtent complètement.
- `ABY_TEST=bourg` + `ABY_CLOSE=1` : forgeron, marchande, tisserande, vieil homme assis, promeneurs, rumeur après le Gardien.
- `ABY_TEST=relief` : captures de la crête nord, des falaises est, des collines ouest et de l'étang.
- Statut (`scripts/status.gd`, `G.status`) : 5 aptitudes (Force, Endurance, Dextérité, Agilité, Magie) de 0 à 999, rangs I → S. **Tout gain passe par `G.status.gain(aptitude, x)`** au moment de l'acte réel (coup porté → Force dans `enemy.take_hit`, coup reçu → Endurance, contre → Dextérité, esquive parfaite / roulade qui évite → Agilité, sort lancé → Magie) ; le gain ralentit quand l'aptitude grandit. Il reste « en attente » jusqu'à la mise à jour au **Registre d'Aldric** (poste `statut` devant son banc). Les effets se lisent seulement via `G.status` (`dmg_mult`, `max_hp`, `counter_bonus`…), jamais en dur dans le héros.
- Techniques (`Status.TECHS`) : nées d'un compteur de `G.stats` (contres parfaits, esquives parfaites, `chutes`, `survies`) et éveillées à la mise à jour. Niveau 2 = Gardien vaincu + une aptitude ≥ E ; les aptitudes repartent de I mais l'acquis reste (`banked`). Sauvegarde `user://statut.json` (jamais en test).
- Bulles des habitants : **un seul parle à la fois** (`villager._speaker`), le plus proche du joueur reprend la parole. Un Label3D s'efface en fondant `modulate` **et** `outline_modulate` (sinon le contour reste en fantôme), puis `visible = false`.
- Les animations d'interface se comptent en `G.real_dt` (indépendantes du ralenti) ; en test sous xvfb le jeu tourne lentement : attendre un événement (`["callout", texte]`) plutôt qu'une durée fixe.
- Un script préchargé par `game.gd` (autoload) ne doit **jamais** écrire `G.` (la vérification `--check-only` du workflow échoue : « Failed to compile depended scripts ») : lui passer le nœud (`status.g = self`).
- **Sorts appris en jouant** (`Status.SPELLS`, `G.status.spells`, `G.status.loadout`) : l'équipement ne donne plus aucun sort. Trois familles = les trois emplacements du moyeu (casque = Protection, plastron = Puissance, bottes = Mouvement). Gestes de base connus dès le départ (Garde, Fureur, Pas de vent) ; les autres naissent d'un acte réel (`stat` de `G.stats` ou `kills:<espèce>`) et s'éveillent à la mise à jour au registre : Souffle clair = 12 brins de lin cueillis (`lin_recolte`), Toile collante = 3 toiles vues cracher à moins de 16 m (`toiles_vues`, apprentissage par le regard), Embrasement = 4 brutes, Roulade = 3 rôdeurs. Un sort neuf prend la place du geste de base de son emplacement ; on choisit ensuite dans l'onglet « Sorts » du registre (`G.status.choose`).
- Équipement = outil et économie : qualités `bonus` (`hp`, `armor`, `dmg`, `speed`, `regen`) lues par `G.gear_bonus()`, affichées par `G.gear_text()`. La sauvegarde garde aussi sorts, moyeu, argent, sac et équipement.
- Un chiffre (Label3D) qui s'efface doit fondre aussi `outline_modulate` ; et ne jamais réécrire `outline_modulate` juste après l'avoir mis à 0 (le « 1 » noir du préchauffage restait visible sous le héros).
- Monstre en Retour coincé (pas de progrès 2 s) : à moins de 3 m du camp il s'y arrête, plus loin et à plus de 24 m du joueur il rejoint son camp (sinon MONSTRE_BLOQUE intermittent aux falaises est).
- `ABY_TEST=sorts` : cueillette réelle jusqu'à 12 brins, observation des tisseuses à 5–8 m, page Sorts avant/après la mise à jour, choix, Toile puis Souffle lancés.
- `ABY_TEST=statut` : Aldric appelle, registre avant/pendant/après, techniques éveillées, niveau 2 (sceau), « Dernier instant » en combat, « Pas de l'ombre ». `ABY_TEST=proto` finit au registre avec ce que la partie a vraiment donné.

## Retours du créateur (à appliquer en priorité)

- 26 nov. : « pas si mal, mais tu peux faire beaucoup mieux » → tout améliorer : monde plus beau, combat plus fort, profondeur Albion, monde plus grand (dans l'ordre de construction).
- 26 nov. : l'interface façon Albion est validée (moyeu de sorts, récolte à gauche du moyeu, mini-carte en losange).

## Atelier de nuit

Une session programmée (chaque nuit à 2 h 36, heure de Paris) applique cette charte seule : état des lieux, un chantier fini, tests, APK, compte rendu.
Derniers chantiers faits : progression par le jeu, 2e brique (28 nov. : sorts appris en jouant — cueillette, regard, chasse —, onglet Sorts au registre, équipement à qualités, sauvegarde complète ; chiffre fantôme « 1 » sous le héros et monstre coincé au retour corrigés) ; progression par le jeu, 1re brique (statut façon DanMachi au Registre d'Aldric : 5 aptitudes nourries par les actes réels, 4 techniques nées des exploits — Dernier instant, Pas de l'ombre, Briseur, Ténacité —, niveau 2 par le Gardien) ; bulles des habitants qui se chevauchaient corrigées ; bourg vivant (Bran le forgeron, Maëlle la marchande, Ysolde la tisserande, le vieil Aldric, Jehan et Mahaut qui se promènent ; ils parlent de tes exploits) ; nouvelle espèce, la Tisseuse de mousse (bois des tisseuses, soie, Capuche de tisseuse) ; réactions des monstres (recul, titubement, chute), contres et esquives parfaites ; héros habillé (tenue de rôdeur, épée et bouclier), bourg enrichi (forge, tisserand, marché, place), butin au camp et au repaire ; 1re passe du monde (vent, nuages, papillons, oiseaux, ambiance sonore) ; relief, étang et falaises de la clairière (`scripts/terrain.gd`).
Boss fait : Gardien de cendre (repaire au nord-ouest du camp des brutes, 3 phases, rejetons, pluie de cendres, souffle en cône, Cœur ardent).
Prochain : finir la progression par le jeu — plus de techniques (une par espèce vaincue souvent, une pour la récolte ; la grille du registre doit passer à 3 rangées ou à un onglet), sorts d'arme appris eux aussi (Entaille, Charge, Fracas sont encore donnés) ; puis le système d'esprit.

## Plus tard (idées en attente)

- Dialogues par IA de langage (payant → seulement si un moyen gratuit existe).
- Marché entre joueurs et classements via Supabase (offre gratuite).
- Signalement de bug à trois doigts envoyé sur Supabase.
- Page web gratuite (GitHub Pages) avec la vue du dessus de chaque version.
