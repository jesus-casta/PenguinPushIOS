# PenguinPush · iOS

Juego nativo para iPhone y iPad (iOS 15+), con **SpriteKit y SwiftUI**. La aventura «El primer viaje» contiene **ocho etapas propias**, de muy fáciles a desafíos con tres cajas. Los personajes, mapas y sonidos se incluyen en la app; no necesita servidor ni dependencias externas.

## Abrir y ejecutar

1. Abre `PenguinPush.xcodeproj` en Xcode.
2. Selecciona el esquema **PenguinPush** y un simulador de iPhone/iPad, y pulsa **Run**.
3. Para un dispositivo real, elige tu equipo en **Signing & Capabilities**. El identificador es `es.castanon.PenguinPush`.

## La aventura

El juego abre directamente la partida guardada. No hay pantalla de inicio. El personaje se elige al empezar una nueva partida desde Ajustes.

El mapa ocupa toda la pantalla: flechas, deshacer, reiniciar, vista del mapa y ajustes flotan encima. Ninguna franja se reserva para controles. La cámara cercana sigue al pingüino sin deformar las casillas; puede recortar los extremos de la habitación. El icono de mapa permite **ver el mapa completo** o volver a **seguir al pingüino**. Pellizca para ampliar y arrastra con dos dedos para explorar. Toca una casilla libre para que el pingüino camine hasta ella por el camino más corto, sin mover cajas; las flechas interrumpen el recorrido. Los obstáculos se representan como iglús sobre nieve. También puedes deslizar para moverte o mantener pulsadas las flechas; al soltarlas se descartan los pasos pendientes.

El pingüino balancea el cuerpo, levanta ligeramente el paso y deja huellas que desaparecen. Al empujar se inclina y la caja se desliza; al llegar a una meta cambia de color y hace un pequeño rebote. La cámara acompaña el movimiento. Se respeta Reducir movimiento.

Las ocho habitaciones se desbloquean en orden. Puedes repetir las que ya has abierto desde Ajustes. La primera enseña un empuje sencillo, después llegan dos cajas, giros, pasillos y decisiones sobre el orden de las entregas. La última tiene tres cajas. Cada etapa incluye una pista. La aventura usa un ambiente helado; los datos admiten capítulo y dificultad para futuros viajes temáticos.

Se guardan posición, cajas, contadores, historial de deshacer, personaje y etapas abiertas después de cada movimiento y al pasar a segundo plano. El guardado anterior a esta aventura se conserva en `session-before-adventure.json`; las partidas nativas de tutoriales seleccionados se adaptan a las habitaciones ampliadas cuando su historial es válido.

## Arquitectura

- `Sokoban.swift`: reglas Swift, validación de niveles y de partidas mediante reproducción de movimientos legales.
- `PenguinScene.swift`: mundo SpriteKit, cámara, personajes, cajas y animaciones. Suelo y paredes se crean al cargar una habitación; no se reconstruyen por fotograma.
- `GameModel.swift` y `GameStore.swift`: progresión y guardado JSON mediante sustitución atómica en Application Support.
- `NativeBoardView.swift`: vista SpriteKit, teclado, zoom y controles con repetición y cancelación al soltar.
- `NativeAudio.swift`: efectos sintetizados con AVAudioPlayer, respetando el modo silencio y la música de otras aplicaciones.

`PenguinPush/Resources/NativeGame` contiene únicamente los ocho mapas JSON y el atlas de personajes que se empaquetan en la app. `data/adventure.json` es la fuente de la campaña. Los antiguos mapas de Boxxle I, clásicos y tutoriales quedan en `Resources/Game` como referencia para pruebas; no se incluyen ni se ejecutan en la aplicación. No se utiliza WKWebView.

Una importación de solo lectura puede recuperar preferencias del almacenamiento SQLite de la versión web. Un guardado nativo existente tiene prioridad.

## Validación

```sh
node scripts/export-native-levels.cjs
scripts/check-native.sh
xcodebuild -project PenguinPush.xcodeproj -scheme PenguinPush -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`check-native.sh` verifica que la app solo exporta ocho etapas, comprueba sus soluciones y compara las reglas Swift con la referencia en 178 mapas y 28.480 operaciones. También comprueba guardado, deshacer después de relanzar, rechazo de datos inválidos e importación SQLite UTF-16. `scripts/solve-adventure.cjs` reproduce la búsqueda de soluciones por número de empujes; los resultados están en `data/adventure-solutions.json`.

En Xcode, **Product → Test** (⌘U) ejecuta `PenguinPushUITests`: entrada directa, movimiento, recuperación, deshacer, personaje, controles en horizontal, desbloqueo progresivo y recorrido por toque evitando cajas. Las capturas quedan adjuntas al resultado de las pruebas. En Debug, estas pruebas usan un archivo de guardado separado.

La automatización de GitHub verifica las reglas y compila para simulador sin firma. No publica la app. La fluidez, los gestos y el sonido deben comprobarse también en un dispositivo real antes de distribuirla.

La procedencia de los mapas y los recursos se documenta en [ORIGINAL_LEVELS.md](ORIGINAL_LEVELS.md).
