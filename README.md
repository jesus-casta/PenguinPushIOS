# PenguinPush · iOS

Proyecto Xcode para iPhone y iPad (iOS 15+). Incluye **50 mapas clásicos de Sokoban**, **12 tutoriales**, dos pingüinos seleccionables sin libro, cajas de pescado, animaciones y efectos sonoros originales.

## Abrir y ejecutar

1. Clona este repositorio en el Mac.
2. Abre `PenguinPush.xcodeproj` con Xcode.
3. Selecciona el esquema **PenguinPush** y un simulador de iPhone/iPad, y pulsa Run.
4. Para un dispositivo real, elige tu equipo en **Signing & Capabilities**. El identificador inicial es `es.castanon.PenguinPush`; puedes cambiarlo si necesitas uno diferente.

No necesitas CocoaPods, Swift Package Manager ni una conexión a un servidor para jugar. Los recursos están incluidos en la aplicación.

## Arquitectura

La aplicación usa SwiftUI y un contenedor **WKWebView** para el juego HTML/Canvas compartido. La lógica y las animaciones se ejecutan en ese motor; no es una reimplementación nativa del tablero en Swift. Esto mantiene idénticos los mapas y las reglas en las tres versiones.

`PenguinPush/Resources/Game` contiene todo el juego. El proyecto copia esa carpeta al paquete de la app. WKWebView utiliza almacenamiento persistente, solo permite navegar por los recursos locales y pausa los sonidos al pasar a segundo plano. Los efectos respetan el modo silencio de iOS y permiten escuchar música de otras aplicaciones.

El progreso guarda los niveles completados, mejores contadores y preferencias. Una partida sin terminar se reinicia al cerrar el proceso.

## Validación

```sh
node scripts/check-bundle.cjs
xcodebuild -project PenguinPush.xcodeproj -scheme PenguinPush -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

La automatización de GitHub compila para simulador sin firma. No sube nada a App Store Connect. El uso real de WKWebView, los gestos y el audio se deben probar también en un iPhone/iPad antes de distribuir la aplicación.

El código compartido se edita en [PenguinPushHTML](https://github.com/jesus-casta/PenguinPushHTML) y se sincroniza con su script `scripts/sync-native.py`. `bundle-manifest.json` permite comprobar la copia incluida.

La procedencia de los mapas está en [ORIGINAL_LEVELS.md](ORIGINAL_LEVELS.md). Los clásicos son de Thinking Rabbit; su distribución permanece intacta.
