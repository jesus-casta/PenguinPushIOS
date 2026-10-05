import SwiftUI

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = GameModel()
    @State private var wantsNewGame = false
    var body: some View {
        ZStack {
            NativeBoardView(model: model).ignoresSafeArea()
                .accessibilityLabel("Tablero de PenguinPush")
                .accessibilityHint("Toca una casilla para caminar hasta ella sin empujar cajas. Desliza o usa las flechas para empujar.")
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.board?.level.name ?? "PenguinPush").font(.headline)
                        if model.packs.indices.contains(model.packIndex) {
                            Text("ETAPA \(model.levelIndex + 1) DE \(model.packs[0].levels.count) · \(model.board?.level.difficulty ?? "")")
                                .font(.caption2).accessibilityIdentifier("adventureProgress")
                        }
                        Text("\(model.board?.state.moves ?? 0) pasos · \(model.board?.state.pushes ?? 0) empujes · \(model.board?.placed ?? 0)/\(model.board?.goals.count ?? 0)")
                            .font(.caption.monospacedDigit()).accessibilityIdentifier("gameCounters")
                    }
                    .padding(8).background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                    Spacer(minLength: 8)
                    Button { model.settingsOpen = true } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44) }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Ajustes")
                }
                Spacer()
                HStack(alignment: .bottom) {
                    HStack(spacing: 6) {
                        Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                            .accessibilityLabel("Deshacer").disabled(model.board?.history.isEmpty != false)
                        Button { model.load(level: model.levelIndex) } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                            .accessibilityLabel("Reiniciar")
                        Menu {
                            Button("Ver mapa completo") { model.scene.overview() }
                            Button("Seguir al pingüino") { model.scene.resetZoom() }
                            Button("Ampliar") { model.scene.magnify(by: 1.5) }
                            Button("Reducir") { model.scene.magnify(by: 1 / 1.5) }
                        } label: { Image(systemName: "map").frame(width: 44, height: 44) }
                        .accessibilityLabel("Vista del mapa")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .background(Color.black.opacity(0.24), in: Capsule())
                    Spacer(minLength: 8)
                    dpad
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundColor(.white).shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .disabled(!model.active || model.settingsOpen || model.choosingCharacter || model.error != nil)
            if model.showVictory { victory }
            if let error = model.error {
                Text(error).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .sheet(isPresented: $model.settingsOpen, onDismiss: {
            if wantsNewGame { wantsNewGame = false; model.choosingCharacter = true }
        }) { settings }
        .sheet(isPresented: $model.choosingCharacter) { CharacterPicker(model: model) }
        .onChange(of: scenePhase) { model.setActive($0 == .active) }
        .onAppear { model.setActive(scenePhase == .active) }
    }
    private var dpad: some View {
        VStack(spacing: 4) {
            arrow(.up)
            HStack(spacing: 4) { arrow(.left); Color.clear.frame(width: 48, height: 48); arrow(.right) }
            arrow(.down)
        }
    }
    private func arrow(_ direction: MoveDirection) -> some View {
        DirectionButton(direction: direction, enabled: model.canMove, action: { model.move(direction) }, onRelease: model.releaseInput)
            .frame(width: 48, height: 48)
    }
    private var victory: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(model.levelIndex == model.packs[0].levels.count - 1 ? "¡Aventura completada!" : "¡Etapa completada!").font(.title2.bold())
                Text("\(model.board?.state.moves ?? 0) pasos · \(model.board?.state.pushes ?? 0) empujes")
                Button(model.levelIndex == model.packs[0].levels.count - 1 ? "Ver mi aventura" : "Siguiente etapa") { model.next() }.buttonStyle(.borderedProminent)
                Button("Ver tablero") { model.showVictory = false }
                Button("Deshacer") { model.undo() }
            }
            .padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .accessibilityAddTraits(.isModal)
    }
    private var settings: some View {
        NavigationView {
            Form {
                Section {
                    Button("Nueva partida · elegir pingüino") { wantsNewGame = true; model.settingsOpen = false }
                    Text("El primer viaje").font(.headline)
                    Text("Ocho etapas: de los primeros empujes a planificar una entrega completa.").font(.caption)
                    if !model.packs.isEmpty {
                        ForEach(model.packs[0].levels.indices, id: \.self) { i in
                            let level = model.packs[0].levels[i]
                            Button { model.load(level: i); model.settingsOpen = false } label: {
                                HStack {
                                    Image(systemName: model.completed[level.id] != nil ? "checkmark.circle.fill" : i <= model.unlockedLevel ? "circle" : "lock.fill")
                                    VStack(alignment: .leading) { Text(level.name); Text(level.difficulty ?? "").font(.caption).foregroundColor(.secondary) }
                                    Spacer()
                                    if i == model.levelIndex { Text("Aquí").font(.caption) }
                                }
                            }.accessibilityIdentifier("stage-\(i)").disabled(i > model.unlockedLevel)
                        }
                    }
                }

                Section("Sonido") {
                    Toggle("Sonido", isOn: $model.sound)
                    Slider(value: $model.volume, in: 0...1) { Text("Volumen") }
                    Text("Volumen: \(Int(model.volume * 100)) %").font(.caption)
                }
                Section("Cómo jugar") {
                    Text("Empuja las cajas de pescado hasta las marcas. No puedes tirar de ellas. Toca una casilla libre para caminar hasta ella rodeando los iglús y las cajas. Para empujar, desliza sobre el tablero o mantén pulsadas las flechas.")
                    Text("La cámara sigue al pingüino. Pulsa el icono de mapa para ver la habitación completa. Pellizca para ampliar y arrastra con dos dedos para explorar. También puedes usar las flechas o WASD de un teclado; Z deshace y R reinicia.")
                    if model.board?.cornerBlocked == true { Text("Hay una caja atrapada en una esquina. Usa Deshacer.").foregroundColor(.orange) }
                }
                Section("Partida") {
                    if let error = model.saveError { Text(error).foregroundColor(.red); Button("Reintentar guardado") { model.save() } }
                    else { Text("La partida se guarda automáticamente en este dispositivo después de cada movimiento.") }
                }
                Section("Esta aventura") {
                    Text(model.board?.level.hint ?? "Empuja cada caja hasta su marca.")
                    Text("Ocho habitaciones de PenguinPush. Nuevos viajes podrán tener sus propios ambientes y retos.").font(.caption)
                }
            }
            .navigationTitle("Ajustes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { model.settingsOpen = false } } }
        }.navigationViewStyle(.stack)
    }
}

private struct CharacterPicker: View {
    @ObservedObject var model: GameModel
    @State private var selection = 0
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("¿Quién va a jugar?").font(.title.bold())
                HStack(spacing: 12) {
                    ForEach(0..<2) { character in
                        Button { selection = character } label: {
                            VStack {
                                if let image = portrait(character) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160) }
                                Text(character == 0 ? "Pingüino" : "Pingüina").font(.headline)
                            }
                            .padding(12).frame(maxWidth: .infinity)
                            .background(selection == character ? Color.blue.opacity(0.18) : Color.gray.opacity(0.08))
                            .cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(selection == character ? Color.blue : .clear, lineWidth: 2))
                        }.accessibilityAddTraits(selection == character ? .isSelected : [])
                    }
                }
                Text("Se empezará desde la primera etapa de la aventura.").font(.caption).foregroundColor(.secondary)
                Button("Empezar nueva partida") { model.newGame(character: selection) }.buttonStyle(.borderedProminent)
            }
            .padding(24).navigationTitle("Nueva partida")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { model.choosingCharacter = false } } }
        }
        .navigationViewStyle(.stack).onAppear { selection = model.character }
    }
    private func portrait(_ character: Int) -> UIImage? {
        guard let url = Bundle.main.url(forResource: "penguins", withExtension: "png", subdirectory: "NativeGame"),
              let atlas = UIImage(contentsOfFile: url.path)?.cgImage,
              let cropped = atlas.cropping(to: CGRect(x: 0, y: character * atlas.height / 2, width: atlas.width / 4, height: atlas.height / 2)) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
