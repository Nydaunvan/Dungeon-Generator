class_name Seeds
extends RefCounted
## Graines des parties vérifiables : une graine (entier) fournie par le serveur détermine TOUT le hasard des règles.
## Le même (graine, paramètres, actions) doit redonner exactement la même partie, sur n'importe quelle machine : c'est ce qui permet
## au serveur de rejouer une partie et d'en recalculer le score. N'utiliser ici que de l'arithmétique entière (aucun flottant).

const MASK := 0x7FFFFFFFFFFFFFFF      ## graines positives sur 63 bits

## Graine dérivée d'une graine de partie et d'une étiquette (ex. « expedition », 2) : indépendante pour chaque (étiquette, indice).
static func derive(base: int, tag: String, index: int = 0) -> int:
	var h: int = base ^ 0x5851F42D4C957F2D
	for b in tag.to_utf8_buffer():
		h = (h ^ int(b)) * 0x100000001B3          # FNV-1a (64 bits, débordement entier voulu)
	h = (h ^ index) * 0x100000001B3
	h ^= (h >> 33)
	h *= 0x62A9D9ED799705F5                        # mélangeur de bits
	h ^= (h >> 28)
	return h & MASK

## Graine texte (côté serveur : identifiant ou chaîne) → entier stable.
static func from_text(s: String) -> int:
	return derive(0x1234ABCD, s)

## Exécute `work` avec le hasard GLOBAL (randi, randf, shuffle, pick_random…) réglé sur `seed_value`, puis rend le hasard global
## imprévisible : le reste du jeu (effets visuels, etc.) ne devient pas déterministe. Pour du code synchrone uniquement (aucun await).
static func with_global(seed_value: int, work: Callable) -> Variant:
	seed(seed_value)
	var out = work.call()
	randomize()
	return out
