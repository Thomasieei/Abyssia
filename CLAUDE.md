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

- Modèle de base Quaternius = corps nu : il faut le pack **Modular Character Outfits – Fantasy** (demandé au créateur) ; la tenue de cuir peinte est provisoire.
- Épée `Human_Sword.fbx` dans `hand_r` : rotation (0, −90, −90), matériau acier remplacé (texture manquante = rose).
- Les textures Quaternius sont trop claires sous ce rendu : teinter les rochers (0,66 0,63 0,58), cailloux et bordures.
- Les panneaux Label3D doivent être `fixed_size` (sinon énormes près de la caméra).
- Les chiffres de dégâts doivent s'empiler (sinon illisibles).
- Les effets au sol en mélange additif deviennent blancs sur l'herbe claire : mélange normal.
- Test : attendre la capture (`await _shot`) avant l'étape suivante.
- Ne pas placer de grand bâtiment juste au sud du point d'apparition (la caméra regarde du sud).

## Retours du créateur (à appliquer en priorité)

- 26 nov. : « pas si mal, mais tu peux faire beaucoup mieux » → tout améliorer : monde plus beau, combat plus fort, profondeur Albion, monde plus grand (dans l'ordre de construction).
- 26 nov. : l'interface façon Albion est validée (moyeu de sorts, récolte à gauche du moyeu, mini-carte en losange).

## Atelier de nuit

Une session programmée (chaque nuit à 2 h 36, heure de Paris) applique cette charte seule : état des lieux, un chantier fini, tests, APK, compte rendu.
Dernier chantier fait : 1re passe du monde (vent, nuages, papillons, oiseaux, ambiance sonore). Prochain : relief, eau et falaises de la clairière.

## Plus tard (idées en attente)

- Dialogues par IA de langage (payant → seulement si un moyen gratuit existe).
- Marché entre joueurs et classements via Supabase (offre gratuite).
- Signalement de bug à trois doigts envoyé sur Supabase.
- Page web gratuite (GitHub Pages) avec la vue du dessus de chaque version.
