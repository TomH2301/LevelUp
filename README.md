# LevelUp

iOS-Fitness-RPG-App. Entwicklung ohne eigenen Mac — Details siehe Konzeptdokument.

## Projektstruktur

- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen)-Spezifikation. Ersetzt das `.xcodeproj`, das normalerweise per Xcode-GUI entsteht. Das `.xcodeproj` selbst wird nicht committet, sondern bei jedem Build neu generiert (siehe `.gitignore`).
- `Sources/LevelUp/` — SwiftUI-Quellcode.
- `.github/workflows/build.yml` — baut die App auf einem kostenlosen macOS-Runner und lädt eine unsignierte `.ipa` als Artifact hoch.

## Lokal bauen (nur mit Mac nötig)

```
xcodegen generate
open LevelUp.xcodeproj
```

## Bauen ohne Mac

1. Push nach `main` (oder manuell über den Tab "Actions" → "Build iOS App" → "Run workflow").
2. Nach ca. 5–10 Minuten liegt unter dem jeweiligen Workflow-Run ein Artifact `LevelUp-ipa` mit der `.ipa` bereit.
3. `.ipa` herunterladen und per AltServer (Windows) aufs iPhone sideloaden.
