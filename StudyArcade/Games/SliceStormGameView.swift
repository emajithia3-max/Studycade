import SwiftUI

private struct SliceObject: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let emoji: String
    let isBomb: Bool
    var sliced = false
    var opacity: Double = 1.0
}

struct SliceStormGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var score = 0
    @State private var lives = 3
    @State private var objects: [SliceObject] = []
    @State private var slicePoints: [CGPoint] = []
    @State private var timer: Timer?
    @State private var physicsTimer: Timer?
    @State private var combo = 0
    @State private var showCombo = false
    @State private var gameOver = false
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let fruits = ["🍎", "🍊", "🍋", "🍇", "🍉", "🍓", "🥝", "🍑", "🍍", "🫐"]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Slice trail
                if slicePoints.count > 1 {
                    Path { path in
                        path.move(to: slicePoints[0])
                        for point in slicePoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.white, lineWidth: 3)
                    .shadow(color: .cyan, radius: 6)
                }

                // Flying objects
                ForEach(objects) { obj in
                    Text(obj.isBomb ? "💣" : obj.emoji)
                        .font(.system(size: obj.sliced ? 30 : 50))
                        .opacity(obj.opacity)
                        .position(obj.position)
                        .scaleEffect(obj.sliced ? 0.3 : 1.0)
                }

                // HUD
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < lives ? "heart.fill" : "heart")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                        }
                        Spacer()
                        if showCombo && combo > 1 {
                            Text("\(combo)x COMBO!")
                                .font(.title3).bold()
                                .foregroundColor(.yellow)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                        Text("\(score)")
                            .font(.title).bold()
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    Spacer()
                }

                // Flashcard overlay
                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("⚡ Bonus Round ⚡")
                            .font(.headline).foregroundColor(.yellow)
                        Text(card.front)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                        if showAnswer {
                            Text(card.back)
                                .font(.title3).foregroundColor(.green)
                                .padding()
                            HStack(spacing: 20) {
                                Button("Wrong") {
                                    card.markSeen(correct: false)
                                    resumeFromFlashcard()
                                }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.red).foregroundColor(.white).cornerRadius(10)
                                Button("Got it! +50") {
                                    card.markSeen(correct: true)
                                    score += 50
                                    resumeFromFlashcard()
                                }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.green).foregroundColor(.white).cornerRadius(10)
                            }
                        } else {
                            Button("Show Answer") { withAnimation { showAnswer = true } }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                        }
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.9)).cornerRadius(20)
                    .padding(24)
                }

                // Game Over
                if gameOver {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Game Over").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !gameOver && !flashcardActive {
                            slicePoints.append(value.location)
                            if slicePoints.count > 12 { slicePoints.removeFirst() }
                            checkSlice(at: value.location)
                        }
                    }
                    .onEnded { _ in slicePoints.removeAll() }
            )
            .onAppear {
                screenSize = geo.size
                startGame()
            }
            .onDisappear { stopTimers() }
        }
        .navigationTitle("Slice Storm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            spawnWave()
        }
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            updatePhysics()
        }
    }

    private func spawnWave() {
        let count = Int.random(in: 1...3)
        for _ in 0..<count {
            let isBomb = Int.random(in: 0...6) == 0
            let x = CGFloat.random(in: 40...(screenSize.width - 40))
            let vx = CGFloat.random(in: -60...60)
            let vy = CGFloat.random(in: -500 ... -350)
            let obj = SliceObject(
                position: CGPoint(x: x, y: screenSize.height + 40),
                velocity: CGPoint(x: vx, y: vy),
                emoji: fruits.randomElement()!,
                isBomb: isBomb
            )
            objects.append(obj)
        }

        // Flashcard chance every wave
        if Int.random(in: 0...8) == 0 && !studySet.flashcards.isEmpty {
            injectFlashcard()
        }
    }

    private func updatePhysics() {
        let dt: CGFloat = 0.016
        for i in objects.indices {
            objects[i].position.x += objects[i].velocity.x * dt
            objects[i].position.y += objects[i].velocity.y * dt
            objects[i].velocity.y += 600 * dt // gravity
        }
        // Remove off-screen objects (missed fruits lose nothing - just fall)
        objects.removeAll { $0.position.y > screenSize.height + 80 && !$0.sliced }
        objects.removeAll { $0.sliced && $0.opacity <= 0 }
    }

    private func checkSlice(at point: CGPoint) {
        var slicedAny = false
        for i in objects.indices {
            guard !objects[i].sliced else { continue }
            let dist = hypot(point.x - objects[i].position.x, point.y - objects[i].position.y)
            if dist < 40 {
                if objects[i].isBomb {
                    lives -= 1
                    combo = 0
                    withAnimation { showCombo = false }
                    objects[i].sliced = true
                    withAnimation(.easeOut(duration: 0.3)) { objects[i].opacity = 0 }
                    if lives <= 0 { gameOver = true; stopTimers() }
                    return
                }
                objects[i].sliced = true
                withAnimation(.easeOut(duration: 0.4)) { objects[i].opacity = 0 }
                slicedAny = true
                combo += 1
                let points = 10 * combo
                score += points
                withAnimation(.spring()) { showCombo = combo > 1 }
            }
        }
        if !slicedAny && slicePoints.count == 1 {
            combo = 0
            withAnimation { showCombo = false }
        }
    }

    private func injectFlashcard() {
        currentFlashcard = studySet.flashcards.randomElement()
        showAnswer = false
        flashcardActive = true
    }

    private func resumeFromFlashcard() {
        flashcardActive = false
        currentFlashcard = nil
        showAnswer = false
    }

    private func stopTimers() {
        timer?.invalidate()
        physicsTimer?.invalidate()
    }

    private func endGame() {
        stopTimers()
        onGameEnd(score)
        dismiss()
    }
}
