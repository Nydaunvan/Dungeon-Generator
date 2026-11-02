# Compétences vivantes — règles, architecture, équilibrage

Branche `migration/living-skills`. Code : `scripts/rules/living_catalog.gd` (profils), `scripts/rules/living_skills.gd` (moteur), `scripts/ui/living_modal.gd` (fiche),
onglet « Vie des compétences » de `party_modal.gd`. Tests : `tools/check_living_skills.tscn` (15 contrôles). Matrice d'audit : `docs/LIVING_SKILLS_MATRIX.md`
(générée par `tools/living_matrix.tscn`).

## 1. Principe

Chaque sort, talent de classe et instinct d'un héros garde une trace de ce qu'il a vécu avec lui : une **affinité**, un **tempérament** qui dérive, quelques
**souvenirs**, des **liens** avec d'autres compétences, et, quand le joueur le décide, une **évolution**. Garanties de conception :

- **Rien ne change sans choix** : une compétence neuve joue exactement comme avant. Les seuls effets automatiques sont des *manifestations* (texte) et l'*humeur*
  d'une compétence très instable, qui ne retire jamais une action au joueur. Les améliorations viennent d'une évolution *choisie*, définitive, avec un prix.
- **Aucun hasard** : toutes les règles sont des conditions explicites ; les variantes de texte se choisissent par hachage de l'identifiant. Le flux « combat » de
  `GameRng` n'est jamais consommé par ce système (contrôle 10).
- **Inactif** si l'option « Compétences vivantes » est coupée (Paramètres › Graphismes › Compétences vivantes) et **toujours inactif en partie classée** (`gs.run_seed != ""`) : rejeu et
  classement restent identiques à l'original. Toutes les fonctions rendent alors leur entrée inchangée (contrôle 13).
- **Données réelles** : le profil est *calculé* d'après `cfg.spells`, `classTalents` et les familles d'instinct, jamais stocké. Un sort créé dans l'éditeur est donc
  pris en compte automatiquement ; les identifiants ne sont jamais modifiés (contrôle 2).

## 2. Inventaire (audit)

80 sorts (dont 14 ultimes), 210 talents de classe (21 classes), 7 instincts (familles Guerrier, Archer, Roublard, Mage, Prêtre, Druide, Barde) = **297 compétences**.
Il n'existe pas de compétences d'exploration dédiées. 11 statuts (non pris pour des compétences). Voir la matrice pour chaque ligne.

| Famille | Source | Nombre |
|---|---|---|
| offense | sorts de dégâts non physiques | 43 |
| technique | sorts de dégâts physiques | 17 |
| soin | `healSingle`, `healParty` | 10 |
| defense | `shieldSingle` | 3 |
| controle | `sleepGroup`, `dispelSingle` | 3 |
| soutien | `partyUtility`, `selfBuff`, `staminaRestoreSingle` | 4 |
| passif | options de talents de classe | 210 |
| instinct | réflexe de survie de la famille | 7 |

## 3. Tempérament

Sept traits : agressivité `agg`, loyauté `loy`, curiosité `cur`, prudence `pru`, protection `pro`, indépendance `ind`, instabilité `ins` (0-100). Seuls les traits
actifs de la famille existent (`LivingCatalog.FAMILY_TRAITS`). Valeur de naissance : 12 à 28 selon le hachage de l'identifiant. La dérive vécue (`t`) est plafonnée
à **+4 par combat** et **60** au total ; elle vient des événements du combat (coups fatals, boss, sauvetages, jeu à faible PV, partage des dégâts…). Un combat
interrompu par la fuite compte un point de moins par trait.

## 4. Affinité

Réglée en **fin de combat** (`LivingSkills.settle`, appelée par `end_combat_reset`, et à la fuite) d'après le registre du combat :

```
brut  = min(lancers, 6) × 0,25 + 1 (a infligé / soigné / posé un statut) + 1 (a achevé) + 1,5 (a touché un boss)
        + min(3, sauvetages × 1,5) + 1,5 (victoire de justesse)
poids = clamp(XP du combat / (8 + 3 × niveau moyen), 0,2 ; 2)
nouveauté = 1 si l'adversaire principal a été vu < 2 fois parmi les 6 derniers combats, 0,5 si < 4, sinon 0,3        (anti-farming)
gain  = clamp(brut × poids × nouveauté, 0 ; 6)        (fuite : au plus 1)
```

Paliers : 0 étrangère, 10 familière, 25 attachée, 50 liée, 80 fusionnelle. Une compétence délaissée depuis plus de 12 combats perd 0,5 tous les 3 combats.
Un sauvetage ne compte que si le compagnon est encore debout à la fin.

## 5. Souvenirs

Six au plus par compétence, rangés par priorité (décisif, premier maître, sauvetage, de justesse, exceptionnel, premier ennemi, lieu, résistance) ; le moins important
est oublié. Les souvenirs nourrissent la fiche et le texte du carnet.

## 6. Évolutions (28 types, trois proposées par compétence)

Disponible si : affinité ≥ 25 **et** le trait associé à la branche ≥ 40, branche non éveillée. Les trois branches d'une compétence sont choisies par hachage de son
identifiant parmi celles de sa famille (l'orientation d'un talent suit son effet principal). Aucune n'est un simple pourcentage : chacune a un avantage et un prix.

| Famille | Évolution | Effet | Prix |
|---|---|---|---|
| offense / technique | Acharnement | ×1,25 sous 50 % de PV de la cible | — |
| | Précision (cible unique) | perce la résistance (jusqu'à ×1,6) | +10 % d'endurance |
| | Tactique | ×1,3 si la cible porte un statut | ×0,9 sinon |
| | Chasse aux brutes (cible unique) | ×1,25 contre boss ou groupe | ×0,9 contre un isolé |
| | Témérité (offense) | ×1,35 tant que le porteur > 30 % PV | 4 % PV max (jamais mortel) |
| | Prudence | bouclier de 12 % PV max (plafond 30 %) à chaque lancer | ×0,85 dégâts |
| | Vengeance | ×1,3 si un compagnon < 35 % PV | ×0,95 sinon |
| | Balayage (zone) | +12 % par membre touché en plus | ×0,92 contre un seul |
| soin | Compassion | ×1,4 sur un allié < 35 % PV | ×0,8 sur un allié ≥ 70 % |
| | Sacrifice | ×1,3 | 5 % PV max du porteur (jamais mortel) |
| | Préventive | le surplus de soin devient un bouclier (15 % PV max au plus) | — |
| | Attachée | ×1,25 sur le compagnon le plus sauvé | ×0,9 sur les autres |
| defense | Gardienne | bouclier ×1,25, le porteur reçoit 40 % du voile posé sur un autre | — |
| | Réactive | ×1,6 sur un allié < 50 % PV | ×0,85 sinon |
| | Rempart | 35 % du bouclier au compagnon le plus blessé | — |
| controle | Domination | sommeil +1 tour ; la purification laisse 2 tours de Vigueur | +10 % d'endurance |
| | Patience | sommeil +1 tour ; la purification laisse 1 tour de Vigueur | recharge +25 % |
| | Ruse | +5 endurance quand le statut prend (ou qu'une purification retire quelque chose) | — |
| soutien | Mémoire | +8 endurance contre un adversaire déjà croisé 3 fois | — |
| | Relais | recharges raccourcies de moitié de plus ; +4 endurance rendue | — |
| | Veille | 8 % PV max de bouclier à l'allié purifié | — |
| passif | Œil exercé | +6 % de critique contre un adversaire connu (≥ 3) | — |
| | Ancre | −8 % de coups reçus si un compagnon < 35 % PV | — |
| | Second souffle | une fois par combat, +10 % PV à moins de 25 % | — |
| | Veine partagée | 30 % du vol de vie soigne le compagnon le plus blessé | — |
| | Sens affûtés | ×1,12 contre une faiblesse élémentaire | — |
| instinct | Veille | +6 points de réussite | — |
| | Écho | un réflexe réussi charge la jauge d'ultime | — |

Toutes les multiplications de dégâts de ce système sont limitées à **×1,8** (`MULT_CAP`).

## 7. Relations et accords

Deux compétences (même héros ou non) qui se répondent à moins de **3 sorts** d'écart pendant un combat, et dont les écoles/modes correspondent à un accord, tissent un
lien : +1 par combat commun ; niveaux à **3 / 7 / 14** combats. Types : complémentaires, rivales (même famille, héros différents), protectrice (soin/défense avec attaque),
antagonistes (feu/glace, sacré/ombre : tension annoncée, **aucune pénalité**), fusionnelles (même héros, même école, niveau 3). Les accords (niveau ≥ 1) sont :
Embrasement, Givre brisé, Lame chantée, Dormeur éveillé, Bénédiction scellée, Pacte du rempart, Sauvetage vengeur, Équilibre sacré (voir `LivingSkills.COMBOS`).
Au plus 24 liens gardés.

## 8. Humeur et conflits

Instabilité ≥ 45 et porteur < 50 % PV : la compétence s'emballe (×1,2 sur l'effet, +25 % de coût). **Jamais bloquant** : si l'endurance ne couvre pas le surcoût, le sort
se lance au coût de base sans le bonus. Un **pacte d'apaisement** (20 + 5 × niveau pièces d'or, instabilité ≥ 20) retire 15 points d'instabilité.

## 9. Manifestations et lore

Deux au plus par combat, 5 sorts d'écart, variantes (geste / esprit × 2) choisies par hachage ; les manifestations sont des lignes du carnet entre guillemets. Cinq
fragments d'une **ancienne conscience** se révèlent aux seuils 2, 5, 9, 14, 20 de fragments (un fragment par évolution éveillée, boss vaincu, lien de niveau supérieur ;
l'éveil d'une évolution en vaut deux). Le lore reste compatible avec l'univers : l'Atlas noir est une mémoire, pas une carte.

## 10. Architecture

- `LivingCatalog` : pur, sans état (profil, familles, évolutions, instincts).
- `LivingSkills` : règles ; état dans `GameState.living` (champ sauvegardé `living`, `{}` tant que rien n'a servi). Contexte de lancer `ctx` (statique, remis à zéro à chaque sort).
- Crochets dans `combat.gd` (tous sans effet si inactif) : `adjust_cost`, `begin_cast`, `mod_heal`, `mod_shield`, `mod_damage`, `note_hit`, `note_heal`, `note_status_applied`,
  `end_cast`, `note_kill`, `on_party_hurt`, `mod_incoming`, `on_turn`, `on_lifesteal`, `note_instinct`, `instinct_bonus`, `crit_bonus`, `settle`.
- Migration de sauvegarde `SaveMigrations` 19 → 20 (`_v19_to_v20`) ; une ancienne sauvegarde se charge sans état vivant.
- Interface : `LivingModal` + onglet de `PartyModal` ; réglage `Settings.living_skills`.
- Textes : `ui.living.*` (FR/EN, parité vérifiée par `tools/check_lang.py`), sujet « Compétences vivantes » du guide, note du tutoriel (sorts).
- Pour ajouter une évolution : l'ajouter à `LivingCatalog.KINDS` et `FAMILY_KINDS`, ses textes `ui.living.k_<clé>_n/_d`, et son effet dans le crochet concerné.

## 11. Risques d'équilibrage connus

- Les 3 évolutions d'une compétence sont attribuées par hachage : certaines compétences ont de meilleures branches que d'autres (acceptable, mais à surveiller avec des retours).
- Les passifs (210) gagnent moins vite que les sorts (plafond 3 par combat) et n'ont qu'une évolution chacun parmi cinq orientations : leur effet est volontairement modeste.
- Témérité + humeur + accord + adversaire apprécié peut approcher le plafond ×1,8 ; le plafond protège, mais un sort offensif très poussé reste plus rentable qu'un soin poussé.
- Les relations n'existent que pour les couples d'écoles prévus par `COMBOS` : une classe sans école compatible (ex. Guerrier seul) en profite moins hors accords inter-héros.
- Valeurs à ajuster après essais en jeu : `AFF_CAP_COMBAT`, `REL_AT`, `EVOLVE_AFF`, `TRAIT_MIN`, `MULT_CAP`.
