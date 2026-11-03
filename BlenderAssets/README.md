# Avatar-Charaktere (Phase 7, Option B)

`build_character.py` erzeugt aus einem [CharMorph](https://github.com/Upliner/CharMorph)-Basis-Charakter drei Body-Parts — **Körper**, **Underwear**, **Hair** — je als **drei separate, nicht-skelettgebundene** Meshes: `<Name>_Basis.usdz`, `<Name>_Fat.usdz`, `<Name>_Muscular.usdz` (analog `<Name>_Underwear_*.usdz`, `<Name>_Hair_*.usdz`). Macht 9 Dateien pro Geschlecht, 18 insgesamt.

## Unterwäsche &amp; Haare: warum "ausgeschnittene Haut" statt echter Assets

`char.assets`, `char.default_assets`, `char.underwear` sind für `mb_female`/`mb_male` alle leer — CharMorph-db liefert für diese Basis-Charaktere **keine** Kleidung/Haare mit (verifiziert per Skript). Statt eigene Meshes zu modellieren, schneidet `extract_region_object()` einen Höhenbereich (Z-Achse) aus der Körper-Geometrie heraus (Hüfte für Unterwäsche, Scheitel für Haare), versetzt jeden Vertex entlang seiner eigenen Basis-Normale leicht nach außen (verhindert Z-Fighting mit der Haut) und exportiert das Ergebnis als eigenes Objekt mit eigenem Material. Dadurch erben beide automatisch Fat/Muscular — sie sind ja buchstäblich Kopien von Körper-Vertices.

**Bug gefunden &amp; gefixt:** Die ursprüngliche Implementierung nutzte `bpy.ops.object.mode_set` + `bpy.ops.mesh.delete` (Edit-Mode-Operatoren). Das funktionierte für `mb_female`, aber bei `mb_male` leerte es reproduzierbar das **Quell-Mesh** auf 0 Vertices (ein bekanntes Problem: Edit-Mode-Operatoren in `--background`-Skripten können sich auf das falsche Objekt auswirken, wenn der Kontext nicht exakt stimmt). Fix: reines `bmesh`-Scripting ohne `mode_set`/Operatoren — direkt auf dem Mesh-Datenblock, kein Kontext-Umweg.

## Warum drei Dateien statt einer mit Shape Keys?

Ursprünglich wurde ein einziges USDZ mit eingebauten Shape Keys exportiert (Blenders übliche Methode). Das scheiterte in zwei Schritten, beide inzwischen gefunden und dokumentiert:

1. **Blender exportiert Shape Keys immer über ein `UsdSkel`-Skelett**, selbst ohne echte Armature. Apples SceneKit-USD-Importer interpretiert diese Skelett-Bindung fehlerhaft und verzerrt das Mesh massiv beim Rendern (bestätigt: Blender selbst zeigt den Export korrekt, SceneKit zeigt eine kollabierte/verzerrte Form). → Lösung: komplett skelettfreie, statische Meshes exportieren, Morphing selbst in SceneKit-Code zusammenbauen (`SCNMorpher.targets` programmatisch gesetzt, siehe `AvatarView.swift`).
2. **`bpy.ops.object.shape_key_add(from_mix=True)` backt im `--background`-Modus falsche (kollabierte) Geometrie** — unabhängig davon, welche Morph-Werte tatsächlich gesetzt sind (reproduziert sogar mit komplett zurückgesetzten Reglern). Die einzelnen rohen CharMorph-Shape-Keys selbst sind nachweislich korrekt. → Lösung: `Fat`/`Muscular` werden selbst per NumPy aus den Vertex-Deltas der rohen Einzel-Shape-Keys berechnet (`bake_from_deltas()` in `build_character.py`), `from_mix` wird gar nicht mehr benutzt.

## FaceWide (Phase 7.11)

Ein viertes, körperweites Shape-Target `FaceWide` wird zusätzlich gebacken, direkt aus dem Rohschlüssel `L2__Head_SizeX_max` (kein Mass/Tone-Kombi, ein einfacher Einzel-Morph). Anders als Fat/Muscular wird sein Gewicht nicht live aus Tracking-Daten berechnet, sondern einmalig aus Vision-Gesichtslandmarken beim Foto-Kalibrieren (`FaceShapeAnalyzer.swift`) und in `AvatarProfile.faceWidthWeight` gespeichert. Bewusst auf eine Achse beschränkt (Gesichtsbreite) statt der vollen CharMorph-Kopf-Reglerpalette — das Prinzip ist aber identisch erweiterbar auf weitere Achsen.

## Wie „Fat"/„Muscular" berechnet werden

Für jede Körperregion (Bauch, Arme, Beine, Schultern, …) gibt es bei CharMorph einen 2-achsigen „Mass/Tone"-Kombi-Morph mit vier Eckpunkt-Shape-Keys (`max-max`, `max-min`, `min-max`, `min-min`). `build_character.py` nimmt für **Fat** die `_max-min`-Ecke (viel Masse, wenig Tonus) jeder Region, für **Muscular** die `_min-max`-Ecke (wenig Masse, viel Tonus), summiert die Vertex-Deltas aller Regionen relativ zu `Basis` auf (mit `DELTA_SCALE`, um Überlagerungen zwischen benachbarten Regionen abzumildern) und schreibt das Ergebnis direkt in einen neuen, sauberen Shape Key.

**`MUSCULAR_DELTA_SCALE` auf 1.5 erhöht (war 0.75):** Bei 0.75 war der Muskel-Effekt neben dem viel dramatischeren Fat-Effekt (0.5) praktisch unsichtbar — CharMorphs rohe „Tone"-Ecke ist an sich sehr subtil. Bei 2.2 wurde Brust/Bauch/Arme klar sichtbar definiert, aber im Becken-/Leistenbereich entstand eine sichtbare Verzerrung (vermutlich Überlagerung der Gluteus-Region-Deltas bei zu hoher Skalierung). 1.5 ist der per lokalem `render_combined_check.py`-Vergleich bestätigte Sweet Spot: deutlich sichtbare Definition (Schultern, Bauch, Arme, Beine) ohne Geometrie-Artefakte.

## Runtime-Morphing: additive statt normalized, keine manuelle Kalibrierung

**Bug gefunden &amp; gefixt (Phase 7.12):** `SCNMorpher.calculationMode` stand auf `.normalized` — dabei konkurrieren alle Targets (Fat/Muscular/FaceWide) um ein gemeinsames Gewichts-Budget. Folge: ein höherer KFA-Wert (mehr Fat-Gewicht) drückte automatisch das Muscular-Gewicht herunter, die Figur wurde beim Zunehmen sichtbar *dünner* statt dicker, und Muscular ließ sich kaum spürbar erhöhen. Fix: `.additive` — Fat und Muscular sind unabhängige, stapelbare Achsen und müssen sich nicht um ein Budget streiten (siehe `AvatarView.swift`, `loadBodyPart`).

**Manuelle Kalibrierungs-UI entfernt:** Es gab eine Einstellungsansicht (`AvatarCalibrationView`), mit der man Fat/Muscular-Gewichtsgrenzen und eine Kraft-Level-Mischung von Hand einstellen konnte. Explizit unerwünscht — der Avatar soll sich ausschließlich aus echten Körperdaten ableiten, nicht aus manueller Einstellung. Entfernt: die View-Datei, der Kamera-Toolbar-Button, das Sheet, sowie die `trainingInfluence`-Kraft-Level-Mischung in `updateMorphWeights()`. Die Gewichts-Normalisierungsgrenzen (KFA 6–35%, Lean-Mass-Index 16–26) sind jetzt feste Konstanten in `AvatarView.swift` statt einstellbarer `AvatarProfile`-Felder.

## Smooth Shading beim Export

**Bug gefunden &amp; gefixt:** Die exportierten statischen Meshes sahen in SceneKit „Minecraft-artig" aus — blockig, ohne weiche Konturen — obwohl Blenders eigene Workbench-Vorschau glatt aussah. Ursache: `export_shape_as_static()` baut pro Shape-Key ein komplett neues `bpy.data.meshes.new(...)`-Objekt aus rohen Vertex-Koordinaten; dabei wird das `use_smooth`-Flag der Polygone nicht automatisch gesetzt (Default ist flach). Fix: nach `foreach_set("co", ...)` wird für jedes Polygon `poly.use_smooth = True` gesetzt, bevor exportiert wird.

## Einmaliges Setup (bereits erledigt, hier nur zur Doku)

1. Blender 5.2+ installieren.
2. [CharMorph-Addon](https://github.com/Upliner/CharMorph/releases/latest) herunterladen und per `bpy.ops.preferences.addon_install` + `addon_enable` installieren.
3. [CharMorph-db](https://github.com/Upliner/CharMorph-db) (Charakterdaten, ~1,1 GB) in `<Blender-Addons-Pfad>/CharMorph/data/` kopieren.

## Charaktere neu erzeugen

```
blender --background --python build_character.py -- mb_female LevelUp_Female
blender --background --python build_character.py -- mb_male   LevelUp_Male
```

Erzeugt `LevelUp_Female_Basis/Fat/Muscular.usdz`, `LevelUp_Female_Underwear_Basis/Fat/Muscular.usdz`, `LevelUp_Female_Hair_Basis/Fat/Muscular.usdz` (und analog für Male) — 9 Dateien pro Geschlecht. Alle danach nach `Sources/LevelUp/Resources/` kopieren.

## Vor jedem iOS-Push: lokal in Blender verifizieren

`render_check.py` importiert eine exportierte `.usdz` zurück und rendert einen Screenshot mit Workbench-Solid-Shading (zeigt Normalen-/Schattierungsfehler zuverlässig, anders als ein dunkel beleuchteter EEVEE-Render):

```
blender --background --python render_check.py -- "<Pfad>\LevelUp_Female_Fat.usdz" "<Pfad>\check.png"
```

Das prüft Export-Korrektheit (Topologie, Normalen, plausible Silhouette), aber **nicht** SceneKit-spezifisches Verhalten — dafür bleibt der eigentliche Geräte-Test nötig.

`render_combined_check.py` macht dasselbe für Körper+Unterwäsche+Haare zusammen (prüft, ob die drei Teile richtig zueinander sitzen):

```
blender --background --python render_combined_check.py -- "<Pfad>\LevelUp_Female" "Basis" "<Pfad>\check.png"
```

## SpikeTest/

Der ursprüngliche Validierungs-Test (Kugel mit einem Shape Key), mit dem der grundsätzliche Export-Pfad Blender → USDZ → SceneKit `SCNMorpher` bestätigt wurde, bevor der echte Charakter gebaut wurde.
