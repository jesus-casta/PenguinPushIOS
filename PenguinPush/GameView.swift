import SwiftUI

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = GameModel()
    @State private var wantsNewGame = false
    var body: some View {
        ZStack {
            NativeBoardView(model: model).ignoresSafeArea()
                .accessibilityLabel("Tablero de PenguinPush")
                .accessibilityHint("Desliza para mover el pingüino. Usa las flechas para movimientos precisos.")
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.board?.level.name ?? "PenguinPush").font(.headline)
                        if model.packs.indices.contains(model.packIndex) {
                            Text("\(model.levelIndex + 1) / \(model.packs[model.packIndex].levels.count) · \(model.packs[model.packIndex].name)")
                                .font(.caption2)
                        }
                        Text("\(model.board?.state.moves ?? 0) pasos · \(model.board?.state.pushes ?? 0) empujes · \(model.board?.placed ?? 0)/\(model.board?.goals.count ?? 0)")
                            .font(.caption.monospacedDigit()).accessibilityIdentifier("gameCounters")
                    }
                    .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    Spacer(minLength: 8)
                    Button { model.settingsOpen = true } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44) }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).accessibilityLabel("Ajustes")
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { model.undo() } label: { Label("Deshacer", systemImage: "arrow.uturn.backward") }
                            .disabled(model.board?.history.isEmpty != false)
                        Button { model.load(level: model.levelIndex) } label: { Label("Reiniciar", systemImage: "arrow.clockwise") }
                        Menu {
                            Button("Ajustar tablero") { model.scene.resetZoom() }
                            Button("Ampliar") { model.scene.magnify(by: 1.5) }
                            Button("Reducir") { model.scene.magnify(by: 1 / 1.5) }
                        } label: { Label("Zoom", systemImage: "plus.magnifyingglass") }
                    }
                    .font(.caption.weight(.semibold)).padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    Spacer(minLength: 8)
                    dpad
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundColor(Color(UIColor(hex: 0x214454)))
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
                Text("¡Todo en su sitio!").font(.title2.bold())
                Text("\(model.board?.state.moves ?? 0) pasos · \(model.board?.state.pushes ?? 0) empujes")
                Button("Siguiente nivel") { model.next() }.buttonStyle(.borderedProminent)
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
                    if model.packs.indices.contains(model.packIndex) {
                        Picker("Colección", selection: Binding(get: { model.packIndex }, set: { model.load(pack: $0, level: 0) })) {
                            ForEach(model.packs.indices, id: \.self) { i in Text(model.packs[i].name).tag(i) }
                        }
                        Picker("Nivel", selection: Binding(get: { model.levelIndex }, set: { model.load(level: $0) })) {
                            ForEach(model.packs[model.packIndex].levels.indices, id: \.self) { i in
                                let level = model.packs[model.packIndex].levels[i]
                                Text((model.completed[level.id] == nil ? "" : "✓ ") + level.name).tag(i)
                            }
                        }
                        let count = model.packs[model.packIndex].levels.filter { model.completed[$0.id] != nil }.count
                        Text("\(count) niveles completados en esta colección").font(.caption)
                    }
                }
                Section("Ambiente y sonido") {
                    Picker("Ambiente", selection: Binding(get: { model.theme }, set: model.changeTheme)) {
                        Text("Iglú de día").tag("ice"); Text("Noche polar").tag("night"); Text("Cabaña de pesca").tag("wood")
                    }
                    Toggle("Sonido", isOn: $model.sound)
                    Slider(value: $model.volume, in: 0...1) { Text("Volumen") }
                    Text("Volumen: \(Int(model.volume * 100)) %").font(.caption)
                }
                Section("Cómo jugar") {
                    Text("Empuja las cajas de pescado hasta las marcas. No puedes tirar de ellas. Desliza sobre el tablero o mantén pulsadas las flechas.")
                    Text("Pellizca para ampliar. Con zoom, arrastra para explorar. También puedes usar las flechas o WASD de un teclado; Z deshace y R reinicia.")
                    if model.board?.cornerBlocked == true { Text("Hay una caja atrapada en una esquina. Usa Deshacer.").foregroundColor(.orange) }
                }
                Section("Partida") {
                    if let error = model.saveError { Text(error).foregroundColor(.red); Button("Reintentar guardado") { model.save() } }
                    else { Text("La partida se guarda automáticamente en este dispositivo después de cada movimiento.") }
                }
                Section("Créditos") { Text("108 mapas de Boxxle I y 50 clásicos atribuidos a Thinking Rabbit. 12 tutoriales de PenguinPush.").font(.caption) }
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
                Text("Se empezará desde el primer nivel de la colección actual.").font(.caption).foregroundColor(.secondary)
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
