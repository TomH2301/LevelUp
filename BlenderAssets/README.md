# Avatar-Charaktere (Phase 7, Option B)

`build_character.py` erzeugt aus einem [CharMorph](https://github.com/Upliner/CharMorph)-Basis-Charakter einen reduzierten, exportfähigen Charakter mit genau zwei Blendshapes:

- **Fat** — alle `*Mass`-Morphs (Bauch, Arme, Beine, …) auf Maximum gebacken
- **Muscular** — alle `*Tone`-Morphs auf Maximum gebacken

Alle übrigen ~1300 granularen CharMorph-Rohmorphs werden nach dem Backen gelöscht, sodass am Ende genau 3 Shape Keys übrig bleiben: `Basis`, `Fat`, `Muscular` — das ist exakt, was SceneKits `SCNMorpher` als zwei unabhängige Morph-Targets lädt.

## Einmaliges Setup (bereits erledigt, hier nur zur Doku)

1. Blender 5.2+ installieren.
2. [CharMorph-Addon](https://github.com/Upliner/CharMorph/releases/latest) herunterladen und per `bpy.ops.preferences.addon_install` + `addon_enable` installieren.
3. [CharMorph-db](https://github.com/Upliner/CharMorph-db) (Charakterdaten, ~1,1 GB) in `<Blender-Addons-Pfad>/CharMorph/data/` kopieren.

## Charaktere neu erzeugen

```
blender --background --python build_character.py -- mb_female LevelUp_Female.usdz
blender --background --python build_character.py -- mb_male   LevelUp_Male.usdz
```

Ergebnis-Dateien danach nach `Sources/LevelUp/Resources/` kopieren.

## SpikeTest/

Der ursprüngliche Validierungs-Test (Kugel mit einem Shape Key), mit dem der Export-Pfad Blender → USDZ → SceneKit `SCNMorpher` bestätigt wurde, bevor der echte Charakter gebaut wurde.
