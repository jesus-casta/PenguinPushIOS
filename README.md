# PenguinPush · iOS

Proyecto Xcode para iPhone y iPad (iOS 15+). Incluye **108 mapas de Boxxle I**, **50 mapas clásicos de Sokoban**, **12 tutoriales**, dos pingüinos seleccionables sin libro, cajas de pescado, animaciones y efectos sonoros originales.

## Abrir y ejecutar

1. Clona este repositorio en el Mac.
2. Abre `PenguinPush.xcodeproj` con Xcode.
3. Selecciona el esquema **PenguinPush** y un simulador de iPhone/iPad, y pulsa Run.
4. Para un dispositivo real, elige tu equipo en **Signing & Capabilities**. El identificador inicial es `es.castanon.PenguinPush`; puedes cambiarlo si necesitas uno diferente.

No necesitas CocoaPods, Swift Package Manager ni una conexión a un servidor para jugar. Los recursos están incluidos en la aplicación.

## Experiencia móvil

El juego abre directamente la partida guardada y ocupa toda la pantalla, sin pantalla de inicio. La colección predeterminada es Boxxle I. El personaje se elige al pulsar Nueva partida en Ajustes. Las flechas semitransparentes se superponen al tablero y repiten al mantenerlas pulsadas; también se puede deslizar. Ajustes permite elegir colección, nivel, ambiente y volumen. El zoom permite explorar mapas grandes. Se respeta la preferencia de reducir movimiento.

Esta aplicación ejecuta el juego de forma nativa en iOS, con SpriteKit y SwiftUI.

## Arquitectura

La lógica del juego está escrita en **Swift** y el tablero se dibuja con **SpriteKit**. SwiftUI presenta los contadores, ajustes, controles superpuestos y selector de personaje. La aplicación no carga HTML, JavaScript ni WKWebView.

- `Sokoban.swift`: reglas, comprobación de niveles, movimientos y deshacer.
- `PenguinScene.swift`: nodos de suelo, paredes, metas, cajas y personajes; solo los elementos móviles se animan, durante 70 ms al caminar y 90 ms al empujar. Se solicita una frecuencia de 60 fps, sin bloquear los gestos mientras se anima un paso.
- `GameModel.swift` y `GameStore.swift`: progreso, preferencias y partida completa; guardado JSON mediante sustitución atómica en Application Support después de cada movimiento y al pasar a segundo plano.
- `NativeBoardView.swift`: vista SpriteKit, teclado, zoom y botones con repetición y cancelación al soltar.
- `NativeAudio.swift`: efectos sintetizados con AVAudioPlayer. Respetan el modo silencio y la música de otras aplicaciones.

`PenguinPush/Resources/NativeGame` es la única carpeta de recursos de juego incluida en el paquete: mapas JSON y atlas de personajes. Los mapas conservan la geometría y orden de las colecciones. `Resources/Game` conserva la referencia anterior para comprobar reglas y exportar datos; no se incluye ni se ejecuta en la aplicación.

La partida guardada recupera posición, cajas, contadores e historial de deshacer. Una importación inicial de solo lectura busca el guardado anterior `penguinpush-v2` en las bases SQLite de almacenamiento local de WebKit (formatos `.localstorage` y `localstorage.sqlite3`) y lo convierte a Swift si está disponible. No se arranca el motor web para importar. Un guardado nativo existente tiene prioridad. Los datos importados se validan reproduciendo movimientos legales antes de usarlos.

## Validación

```sh
node scripts/check-bundle.cjs
scripts/check-native.sh
xcodebuild -project PenguinPush.xcodeproj -scheme PenguinPush -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Para las pruebas de interfaz, selecciona un simulador disponible en Xcode y pulsa **Product → Test** (⌘U). El esquema incluye `PenguinPushUITests`: comprueba entrada directa sin WebView, movimiento, recuperación al relanzar, deshacer, elección de personaje al crear una partida y controles en horizontal. Las capturas quedan adjuntas al resultado de las pruebas. Las pruebas usan un archivo de guardado separado en Debug.

`check-native.sh` compara el motor Swift con la referencia anterior en los 170 niveles y 27.200 operaciones deterministas; comprueba recuperación, historial completo de deshacer, victoria, rechazo de guardados inválidos e importación desde SQLite UTF-16. La automatización de GitHub ejecuta estas comprobaciones y compila para simulador sin firma. No sube nada a App Store Connect. Audio, rendimiento y gestos deben comprobarse también en un iPhone/iPad real antes de distribuir.

Si se actualizan los mapas o el atlas de la referencia, ejecuta `node scripts/export-native-levels.cjs` y después `scripts/check-native.sh`. No sincronices los archivos Swift desde el repositorio HTML. `bundle-manifest.json` sigue verificando la referencia antigua; la prueba nativa compara todos los mapas exportados y los bytes del atlas.

La procedencia de los mapas está en [ORIGINAL_LEVELS.md](ORIGINAL_LEVELS.md). Los clásicos son de Thinking Rabbit; su distribución permanece intacta.
