# Avatar-Charaktere (Phase 7)

`build_character_mh.py` erzeugt aus [MPFB2](https://static.makehumancommunity.org/mpfb/index.html) (MakeHuman Plugin für Blender) pro Geschlecht vier Körperteile — **Body**, **Underwear**, **Hair**, bei Frauen zusätzlich **Bra** — und exportiert jedes als eigenes Binär-Mesh (`<Name>_mesh.bin`) plus zwei Morph-Target-Dateien (`<Name>_Fat.bin`, `<Name>_Muscular.bin`). Dazu kommt je ein `<Geschlecht>_Eyes.usdz` (Augen morphen nicht mit, bleiben ein normales USDZ).

**Ersetzt die ursprüngliche CharMorph-Pipeline** (`build_character.py`, noch im Repo als Referenz). Grund für den Wechsel und alle dabei gefixten Bugs: siehe unten.

## Warum MakeHuman/MPFB2 statt CharMorph

CharMorph/MB-Lab liefert für `mb_female`/`mb_male` **keine** Assets mit (`char.assets == {}` — keine Augen, keine Haare, keine Kleidung), und der selbstgebaute Mass/Tone-Muskel-Morph blieb trotz Tuning zu subtil. MPFB2 hat dagegen **eingebaute, community-abgestimmte** `weight`/`muscle`-Phänotyp-Regler (`scene.mpfb_macropanel_weight/muscle`) und präzise benannte Vertex-Gruppen (`body`, `scalp`, `nipple`, `helper-genital`, `helper-l-eye`, …) statt CharMorphs Z-Bereichs-Rätselraten.

MPFB2 ist als **Blender Extension** installiert (nicht als Legacy-Addon wie CharMorph), ist nach der Installation automatisch aktiv — kein `addon_enable()` nötig:

```
blender --command extension repo-list        # prüft Repos
blender --command extension sync              # synct extensions.blender.org
blender --command extension install blender_org.mpfb --enable
```

(Erfordert `preferences.system.use_online_access = True`, per Default aus — siehe Kommentare in `build_character_mh.py`.)

## Wichtige MPFB2-Eigenheiten, die zu Bugs geführt haben

1. **`weight`/`muscle`-Properties ändern nur die GEOMETRIE, nicht `obj.data.vertices`.** Shape-Key-Mixing passiert nur im ausgewerteten (depsgraph-evaluated) Mesh — `obj.data.vertices[i].co` bleibt immer bei der Basis-Pose. Wer die Positionen nach einer Gewichts-Änderung braucht, muss `obj.evaluated_get(depsgraph).data` lesen, nicht `obj.data`.
2. **Die "Hide helpers"-Mask-Modifier** (Vertex-Gruppe `body`, invert=False) blendet alle Helper-Gruppen aus (Augenhöhlen, Zähne, Zunge, Genitalien, aber auch **`helper-skirt`/`helper-tights`** — interne Kleidungs-Anpass-Platzhalter!). Wird der Modifier einfach entfernt (für stabile Vertex-Indizes beim Baking, siehe Punkt 1), werden diese Platzhalter-Meshes sichtbar — sah aus wie ein knöchellanges Geister-Kleid. Fix: nach dem Entfernen des Modifiers wird explizit auf die `body`-Vertex-Gruppe reduziert (alle anderen Vertices werden per `bmesh` gelöscht), bevor überhaupt gebacken wird.
3. **Keine Genitalien-Modellierung:** `helper-genital` hat **0% Überlappung** mit der `body`-Gruppe — das Reduzieren auf `body` entfernt diese Geometrie bereits vollständig und sauber (keine separate Glättung nötig, kein Loch, da die `body`-Gruppe darunter schon eine neutrale Fläche hat).
4. **Keine Augen-Geometrie:** MPFB hat nur einen Shader-Trick ("procedural eyes", `node_trees/procedural_eyes.json`) — kein echtes Augapfel-Mesh, und Shader-Graphen überleben keinen USD-Export. Deshalb bauen wir selbst zwei einfache UV-Spheres pro Auge (Lederhaut + Iris, `add_eyeball()`), positioniert am `helper-l-eye`/`helper-r-eye`-Gruppenzentrum (das VOR dem Strip auf `body` gemerkt werden muss, da die Gruppe danach nicht mehr existiert).
5. **Z-Band-Filter für BH/Unterwäsche braucht eine X-Begrenzung:** Ein reiner Höhen-Filter (z.B. Brusthöhe) erfasst im T-Pose auch die ausgestreckten Handgelenke, die zufällig auf gleicher Höhe liegen — sichtbar als symmetrische "Donut"-Artefakte an beiden Handgelenken, die erst unter Fat/Muscular auffielen. Fix: zusätzlich auf `|x| < 55% der maximalen (Arm-)Breite` einschränken, siehe `z_band_group()`.

## SceneKit-Vertex-Korrespondenz-Bug (kritischster Fix)

**Symptom am Gerät:** Nach den ersten MakeHuman-Exporten explodierte der Kopf, sobald Fat/Muscular-Gewichte ungleich 0 waren, die Hose saß falsch, generell "sieht nicht menschlich aus" — obwohl jede einzelne exportierte Datei in Blender für sich genommen einwandfrei aussah.

**Ursache:** Die alte Architektur lud Basis/Fat/Muscular als **drei separate `.usdz`-Dateien**, die SceneKit unabhängig voneinander importiert. Damit `SCNMorpher` funktioniert, muss Vertex Nr. N in jeder Datei exakt denselben Punkt meinen. Apples USD-Importer kann Vertices beim Einlesen aber anhand von Position+Normale neu aufteilen — und das potenziell pro Datei unterschiedlich, weil sich die Normalen zwischen den Formen unterscheiden (verschärft durch den Smooth-Shading-Fix, der pro-Vertex statt pro-Fläche-Normalen einführte). Das war nie verifizierbar, nur erhofft.

**Fix:** Kein USD-Import mehr für Körperteile. `build_character_mh.py`s `export_mesh_and_morphs_binary()` schreibt stattdessen ein eigenes, simples Binärformat:

```
<prefix>_mesh.bin:   vertexCount(u32) triangleCount(u32)
                     positions[vertexCount*3] f32   (Basis)
                     normals[vertexCount*3] f32     (Basis)
                     triangleIndices[triangleCount*3] u32
<prefix>_<Shape>.bin: positions[vertexCount*3] f32  (gleiche Vertex-Reihenfolge wie oben)
```

`Sources/LevelUp/Features/Avatar/BinaryMeshLoader.swift` parst das direkt in `SCNGeometry`/`SCNGeometrySource` — keine USD-Importer-Unsicherheit mehr, Vertex-Korrespondenz ist durch den Aufbau selbst garantiert (alle Shapes kommen aus derselben Blender-Mesh, nur mit unterschiedlichen Shape-Key-Positionen). Augen brauchen das nicht (morphen nicht, bleiben normales `.usdz`).

Lokal verifiziert vor dem Swift-Umbau mit `render_binary_check.py` (parst das Binärformat in reinem Python nach, rendert es — Ergebnis war pixelgleich mit dem vorherigen USDZ-Render).

## Wie „Fat"/„Muscular" berechnet werden

`bake_named_shape()` setzt `scene.mpfb_macropanel_weight`/`muscle`, liest die ausgewertete (depsgraph) Mesh-Position und backt sie als benannten Shape-Key (`Fat`, `Muscular`) auf das Basis-Objekt — beide Achsen bewegen sich unabhängig von derselben 0.5-„Durchschnitts"-Baseline zum jeweiligen Maximum (1.0), analog zum additiven Fat/Muscular-Split der alten Pipeline.

## Einmaliges Setup

1. Blender 5.2+ installieren.
2. MPFB2 installieren (siehe oben, einmalig — danach dauerhaft in der Blender-Installation vorhanden).

## Charaktere neu erzeugen

```
blender --background --python build_character_mh.py -- female LevelUp_Female
blender --background --python build_character_mh.py -- male   LevelUp_Male
```

Erzeugt je Geschlecht: `<Name>_Body_mesh.bin` (+ `_Fat.bin`/`_Muscular.bin`), analog `_Underwear_*`, `_Hair_*`, (nur weiblich) `_Bra_*`, sowie `<Name>_Eyes.usdz`. Alle danach nach `Sources/LevelUp/Resources/` kopieren.

## Vor jedem iOS-Push: lokal in Blender verifizieren

`render_binary_check.py` parst ein exportiertes `.bin`-Paar (Mesh + optionaler Morph-Shape) in reinem Python nach und rendert es — das ist die beste verfügbare lokale Verifikation, weil es denselben Parsing-Pfad testet, den auch `BinaryMeshLoader.swift` benutzt (nur eben in Python statt Swift):

```
blender --background --python render_binary_check.py -- "<Pfad>\LevelUp_Female_Body" Fat "<Pfad>\check.png"
blender --background --python render_binary_check.py -- "<Pfad>\LevelUp_Female_Body" "" "<Pfad>\check.png"   # Basis
```

`render_check.py`/`render_combined_check_mh.py` funktionieren weiterhin für die `.usdz`-Dateien (aktuell nur noch `_Eyes.usdz`).

## SpikeTest/

Der ursprüngliche Validierungs-Test (Kugel mit einem Shape Key), mit dem der grundsätzliche Export-Pfad Blender → USDZ → SceneKit `SCNMorpher` bestätigt wurde, bevor der echte Charakter gebaut wurde. Historisch — die aktuelle Pipeline nutzt für Körperteile gar kein USDZ/SCNMorpher-über-USD mehr (siehe oben).

## Bekannte offene Punkte

- Leichte Kerben am Rand des Haar-Patches (Grenze der `scalp`-Vertex-Gruppe) — kosmetisch, nicht weiter verfolgt.
- `AvatarProfile.faceWidthWeight` / `FaceShapeAnalyzer` / die Foto-Kalibrierung erkennen weiterhin Gesichtsbreite aus einem Foto, aber es gibt aktuell kein FaceWide-Morph-Target in der MakeHuman-Pipeline (gab es bei CharMorph) — der Wert wird gespeichert, aber nicht mehr auf den Avatar angewendet. Müsste bei Bedarf wie Fat/Muscular als zusätzliches `.bin`-Morph-Target ergänzt werden.
