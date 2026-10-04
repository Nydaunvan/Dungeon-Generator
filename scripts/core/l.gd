class_name L
extends RefCounted
## Accès aux textes de l'interface : `L.t("clé")` renvoie le texte dans la langue courante (data/lang/fr.json et en.json).
## Les textes à trous restent au format `%s` / `%d` : `L.fa(L.t("clé"), [a, b])`.

static func t(key: String) -> String:
	return TranslationServer.translate(key)

## Texte de la clé avec ses variables nommées : `L.f("clé", {"nom": x})` remplace `{nom}`.
static func f(key: String, vars: Dictionary) -> String:
	return TranslationServer.translate(key).format(vars)

## Traduit un texte issu des données du jeu (nom de classe, sort, objet, statut…), sans clé : le français sert de référence.
## Gère les préfixes d'emoji/ponctuation (« ✨ Sacré ») et les textes en MAJUSCULES.
static func c(s: String) -> String:
	return TranslationServer.translate(s) if s != "" else s

## Texte à trous : les arguments texte (noms issus des données) sont traduits avant le formatage.
static func fa(fmt: String, args) -> String:
	if args is Array:
		var out := []
		for a in args:
			out.append(c(a) if a is String else a)
		return fmt % out
	if args is String:
		return fmt % c(args)
	return fmt % args

## Traduit (clé ou texte de données) puis met en majuscules.
static func u(s: String) -> String:
	return TranslationServer.translate(s).to_upper()
