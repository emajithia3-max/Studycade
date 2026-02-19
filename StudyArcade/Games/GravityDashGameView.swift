import SwiftUI

private struct Obstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isSpike: Bool
}

struct GravityDashGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerY: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var isJumping = false
    @State private var obstacles: [Obstacle] = []
    @State private var score = 0
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var groundY: CGFloat = 0
    @State private var scrollSpeed: CGFloat = 200
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var distance: Int = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let playerSize: CGFloat = 32
    private let gravity: CGFloat = 1200
    private let jumpForce: CGFloat = -480

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Sky
                LinearGradient(colors: [.orange.opacity(0.3), .purple.opacity(0.4), .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Ground
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(height: 60)
                }
                .ignoresSafeArea(edges: .bottom)

                // Obstacles
                ForEach(obstacles) { obs in
                    if obs.isSpike {
                        // Triangle spike
                        Triangle()
                            .fill(Color.red)
                            .frame(width: obs.width, height: obs.height)
                            .position(x: obs.x, y: obs.y - obs.height / 2)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray)
                            .frame(width: obs.width, height: obs.height)
                            .position(x: obs.x, y: obs.y - obs.height / 2)
                    }
                }

                // Player
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cyan)
                    .frame(width: playerSize, height: playerSize)
                    .shadow(color: .cyan, radius: 6)
                    .position(x: 80, y: playerY)
                    .rotationEffect(.degrees(isJumping ? -15 : 0))

                // HUD
                VStack {
                    HStack {
                        Text("\(distance)m")
                            .font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        Text("Score: \(score)")
                            .font(.title3).foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🏃 Speed Boost! 🏃").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! +50") {
                                    card.markSeen(correct: true)
                                    score += 50
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
                        Text("Crashed!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("\(distance)m").font(.title).foregroundColor(.cyan)
                        Text("Score: \(score)").font(.title2).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { jump() }
            .onAppear {
                screenSize = geo.size
                groundY = geo.size.height - 60
                playerY = groundY - playerSize / 2
                startGame()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Gravity Dash")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func jump() {
        guard !gameOver && !flashcardActive else { return }
        if playerY >= groundY - playerSize / 2 - 2 {
            velocity = jumpForce
            isJumping = true
        }
    }

    private func startGame() {
        var spawnCounter: CGFloat = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016

            // Physics
            velocity += gravity * dt
            playerY += velocity * dt
            if playerY >= groundY - playerSize / 2 {
                playerY = groundY - playerSize / 2
                velocity = 0
                isJumping = false
            }

            // Move obstacles
            for i in obstacles.indices {
                obstacles[i].x -= scrollSpeed * dt
            }
            obstacles.removeAll { $0.x < -50 }

            // Spawn
            spawnCounter += scrollSpeed * dt
            if spawnCounter > CGFloat.random(in: 200...350) {
                spawnCounter = 0
                let isSpike = Bool.random()
                let h: CGFloat = isSpike ? 30 : CGFloat.random(in: 30...60)
                let w: CGFloat = isSpike ? 30 : CGFloat.random(in: 20...40)
                obstacles.append(Obstacle(
                    x: screenSize.width + 50,
                    y: groundY,
                    width: w,
                    height: h,
                    isSpike: isSpike
                ))
            }

            // Distance/Score
            distance = Int(scrollSpeed * CGFloat(score + 1) * 0.001)
            score += 1
            scrollSpeed = min(scrollSpeed + 0.05, 400)

            // Collision
            let playerRect = CGRect(x: 80 - playerSize / 2 + 4, y: playerY - playerSize / 2 + 4, width: playerSize - 8, height: playerSize - 8)
            for obs in obstacles {
                let obsRect = CGRect(x: obs.x - obs.width / 2, y: obs.y - obs.height, width: obs.width, height: obs.height)
                if playerRect.intersects(obsRect) {
                    gameOver = true
                    timer?.invalidate()
                    return
                }
            }

            if score % 500 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score / 10)
        dismiss()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
