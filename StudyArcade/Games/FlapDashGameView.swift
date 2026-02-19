import SwiftUI

private struct Pipe: Identifiable {
    let id = UUID()
    var x: CGFloat
    let gapY: CGFloat
    let gapSize: CGFloat
    var passed = false
}

struct FlapDashGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var birdY: CGFloat = 300
    @State private var velocity: CGFloat = 0
    @State private var pipes: [Pipe] = []
    @State private var score = 0
    @State private var gameStarted = false
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var birdRotation: Double = 0
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let gravity: CGFloat = 800
    private let flapForce: CGFloat = -300
    private let pipeWidth: CGFloat = 60
    private let birdSize: CGFloat = 36

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Sky gradient
                LinearGradient(colors: [.cyan, .blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Ground
                VStack {
                    Spacer()
                    Rectangle().fill(Color.green).frame(height: 50)
                }
                .ignoresSafeArea(edges: .bottom)

                // Pipes
                ForEach(pipes) { pipe in
                    // Top pipe
                    Rectangle()
                        .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: pipeWidth, height: pipe.gapY - pipe.gapSize / 2)
                        .position(x: pipe.x, y: (pipe.gapY - pipe.gapSize / 2) / 2)

                    // Bottom pipe
                    Rectangle()
                        .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: pipeWidth, height: geo.size.height - pipe.gapY - pipe.gapSize / 2 - 50)
                        .position(x: pipe.x, y: pipe.gapY + pipe.gapSize / 2 + (geo.size.height - pipe.gapY - pipe.gapSize / 2 - 50) / 2)
                }

                // Bird
                Text("🐤")
                    .font(.system(size: birdSize))
                    .rotationEffect(.degrees(birdRotation))
                    .position(x: 80, y: birdY)

                // Score
                VStack {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .padding(.top, 40)
                    Spacer()
                }

                if !gameStarted && !gameOver {
                    Text("Tap to start!")
                        .font(.title).bold().foregroundColor(.white)
                        .shadow(color: .black, radius: 4)
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🐤 Shield! 🐤").font(.headline).foregroundColor(.yellow)
                        Text(card.front)
                            .font(.title2).bold().foregroundColor(.white)
                            .multilineTextAlignment(.center).padding()
                        if showAnswer {
                            Text(card.back).font(.title3).foregroundColor(.green).padding()
                            HStack(spacing: 20) {
                                Button("Wrong") {
                                    card.markSeen(correct: false)
                                    resumeFromFlashcard(bonus: false)
                                }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.red).foregroundColor(.white).cornerRadius(10)
                                Button("Got it! +5pts") {
                                    card.markSeen(correct: true)
                                    score += 5
                                    resumeFromFlashcard(bonus: true)
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
                    .padding(32).background(Color.black.opacity(0.9)).cornerRadius(20).padding(24)
                }

                if gameOver {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Crashed!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { tap() }
            .onAppear {
                screenSize = geo.size
                birdY = geo.size.height / 2
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Flap Dash")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tap() {
        guard !gameOver && !flashcardActive else { return }
        if !gameStarted {
            gameStarted = true
            startGameLoop()
        }
        velocity = flapForce
    }

    private func startGameLoop() {
        var pipeSpawnCounter: CGFloat = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016

            // Physics
            velocity += gravity * dt
            birdY += velocity * dt
            birdRotation = min(max(Double(velocity) / 10, -30), 60)

            // Pipe movement
            for i in pipes.indices {
                pipes[i].x -= 150 * dt
            }

            // Spawn pipes
            pipeSpawnCounter += 150 * dt
            if pipeSpawnCounter > 220 {
                pipeSpawnCounter = 0
                let gapSize: CGFloat = max(160 - CGFloat(score) * 2, 120)
                let gapY = CGFloat.random(in: (gapSize / 2 + 80)...(screenSize.height - gapSize / 2 - 130))
                pipes.append(Pipe(x: screenSize.width + pipeWidth, gapY: gapY, gapSize: gapSize))
            }

            // Score
            for i in pipes.indices {
                if !pipes[i].passed && pipes[i].x < 80 {
                    pipes[i].passed = true
                    score += 1

                    if score % 10 == 0 && !studySet.flashcards.isEmpty {
                        currentFlashcard = studySet.flashcards.randomElement()
                        showAnswer = false
                        flashcardActive = true
                    }
                }
            }

            // Cleanup
            pipes.removeAll { $0.x < -pipeWidth }

            // Collision
            if birdY > screenSize.height - 50 - birdSize / 2 || birdY < birdSize / 2 {
                gameOver = true
                timer?.invalidate()
                return
            }

            for pipe in pipes {
                let birdX: CGFloat = 80
                if birdX + birdSize / 2 > pipe.x - pipeWidth / 2 && birdX - birdSize / 2 < pipe.x + pipeWidth / 2 {
                    if birdY - birdSize / 2 < pipe.gapY - pipe.gapSize / 2 || birdY + birdSize / 2 > pipe.gapY + pipe.gapSize / 2 {
                        gameOver = true
                        timer?.invalidate()
                        return
                    }
                }
            }
        }
    }

    private func resumeFromFlashcard(bonus: Bool) {
        flashcardActive = false
        velocity = 0
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}
