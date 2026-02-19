import SwiftUI

struct ColorDashGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ballY: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var ballColor: Int = 0
    @State private var obstacles: [ColorObstacle] = []
    @State private var score = 0
    @State private var gameOver = false
    @State private var gameStarted = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var cameraY: CGFloat = 0
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let colors: [Color] = [.red, .yellow, .green, .blue]
    private let gravity: CGFloat = 600
    private let jumpForce: CGFloat = -320

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Obstacles
                ForEach(obstacles) { obs in
                    let screenY = obs.y - cameraY
                    ZStack {
                        // Gate with a gap for the ball color
                        ForEach(0..<4, id: \.self) { i in
                            let startAngle = Double(i) * 90.0 + obs.rotation
                            let endAngle = startAngle + 90.0
                            Circle()
                                .trim(from: startAngle / 360, to: endAngle / 360)
                                .stroke(colors[i], lineWidth: 12)
                                .frame(width: obs.size, height: obs.size)
                        }

                        // Color switch star in center
                        if obs.hasColorSwitch {
                            Circle()
                                .fill(colors[obs.switchToColor])
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .position(x: geo.size.width / 2, y: screenY)
                }

                // Ball
                Circle()
                    .fill(colors[ballColor])
                    .frame(width: 24, height: 24)
                    .shadow(color: colors[ballColor], radius: 8)
                    .position(x: geo.size.width / 2, y: ballY - cameraY)

                // HUD
                VStack {
                    HStack {
                        Spacer()
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.top, 40)
                    Spacer()
                }

                if !gameStarted {
                    Text("Tap to jump!\nMatch the gate color")
                        .font(.headline).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black, radius: 4)
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🎨 Color Shield! 🎨").font(.headline).foregroundColor(.yellow)
                        Text(card.front)
                            .font(.title2).bold().foregroundColor(.white)
                            .multilineTextAlignment(.center).padding()
                        if showAnswer {
                            Text(card.back).font(.title3).foregroundColor(.green).padding()
                            HStack(spacing: 20) {
                                Button("Wrong") {
                                    card.markSeen(correct: false)
                                    flashcardActive = false
                                }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.red).foregroundColor(.white).cornerRadius(10)
                                Button("Got it! +5pts") {
                                    card.markSeen(correct: true)
                                    score += 5
                                    flashcardActive = false
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
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Wrong Color!").font(.largeTitle).bold().foregroundColor(.red)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !gameOver && !flashcardActive else { return }
                if !gameStarted {
                    gameStarted = true
                    startGameLoop()
                }
                velocity = jumpForce
            }
            .onAppear {
                screenSize = geo.size
                ballY = geo.size.height * 0.7
                setupObstacles()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Color Dash")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setupObstacles() {
        for i in 0..<20 {
            let y = ballY - CGFloat(i + 1) * 200
            let obs = ColorObstacle(
                y: y,
                size: 120,
                rotation: Double.random(in: 0...360),
                hasColorSwitch: i > 0 && Int.random(in: 0...2) == 0,
                switchToColor: Int.random(in: 0..<4)
            )
            obstacles.append(obs)
        }
    }

    private func startGameLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016
            velocity += gravity * dt
            ballY += velocity * dt

            // Camera follows ball upward
            let targetCamera = ballY - screenSize.height * 0.7
            if targetCamera < cameraY {
                cameraY = targetCamera
            }

            // Ball falls below screen
            if ballY - cameraY > screenSize.height + 50 {
                gameOver = true
                timer?.invalidate()
                return
            }

            // Rotate obstacles
            for i in obstacles.indices {
                obstacles[i].rotation += 40 * Double(dt)
            }

            // Check color switch pickups & obstacle passing
            for i in obstacles.indices {
                let dist = abs(ballY - obstacles[i].y)
                if dist < 15 && !obstacles[i].passed {
                    if obstacles[i].hasColorSwitch {
                        ballColor = obstacles[i].switchToColor
                    }

                    // Check if ball color matches the gate segment it passes through
                    let angle = obstacles[i].rotation.truncatingRemainder(dividingBy: 360)
                    let segment = Int(angle / 90) % 4
                    // Simplified: ball passes through if its color is one of the 4
                    // In real Color Switch, it checks which quadrant. Simplified here.
                    let passColor = (4 - segment) % 4
                    if ballColor != passColor && !obstacles[i].hasColorSwitch {
                        // Give benefit of the doubt with wider tolerance
                        let tolerance = [passColor, (passColor + 1) % 4]
                        if !tolerance.contains(ballColor) {
                            gameOver = true
                            timer?.invalidate()
                            return
                        }
                    }

                    obstacles[i].passed = true
                    score += 1

                    if score % 8 == 0 && !studySet.flashcards.isEmpty {
                        currentFlashcard = studySet.flashcards.randomElement()
                        showAnswer = false
                        flashcardActive = true
                    }
                }
            }

            // Spawn more obstacles above
            if let highest = obstacles.min(by: { $0.y < $1.y }) {
                if highest.y > cameraY - 200 {
                    let newY = highest.y - 200
                    let obs = ColorObstacle(
                        y: newY,
                        size: 120,
                        rotation: Double.random(in: 0...360),
                        hasColorSwitch: Int.random(in: 0...2) == 0,
                        switchToColor: Int.random(in: 0..<4)
                    )
                    obstacles.append(obs)
                }
            }

            // Cleanup far below
            obstacles.removeAll { $0.y > cameraY + screenSize.height + 200 }
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}

private struct ColorObstacle: Identifiable {
    let id = UUID()
    let y: CGFloat
    let size: CGFloat
    var rotation: Double
    let hasColorSwitch: Bool
    let switchToColor: Int
    var passed = false
}
