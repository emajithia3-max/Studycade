import SwiftUI

private struct Platform: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let isMoving: Bool
    var moveDir: CGFloat = 1
    let isBroken: Bool
}

struct SkyJumpGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerX: CGFloat = 0
    @State private var playerY: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var platforms: [Platform] = []
    @State private var score = 0
    @State private var highestY: CGFloat = 0
    @State private var cameraY: CGFloat = 0
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var tiltX: CGFloat = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let playerSize: CGFloat = 30
    private let gravity: CGFloat = 600
    private let bounceForce: CGFloat = -420

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2), .indigo.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Platforms
                ForEach(platforms) { plat in
                    let screenY = plat.y - cameraY
                    RoundedRectangle(cornerRadius: 6)
                        .fill(plat.isBroken ? Color.red.opacity(0.5) : Color.green)
                        .frame(width: plat.width, height: 12)
                        .position(x: plat.x, y: screenY)
                }

                // Player
                Text("🤸")
                    .font(.system(size: playerSize))
                    .position(x: playerX, y: playerY - cameraY)

                // Height indicator
                VStack {
                    HStack {
                        Text("↑ \(Int(abs(highestY / 10)))m")
                            .font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        Text("Score: \(score)")
                            .font(.headline).foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                // Tilt controls
                HStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { tiltX = -1 }
                        .onLongPressGesture(minimumDuration: 10, pressing: { pressing in
                            tiltX = pressing ? -1 : 0
                        }, perform: {})
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { tiltX = 1 }
                        .onLongPressGesture(minimumDuration: 10, pressing: { pressing in
                            tiltX = pressing ? 1 : 0
                        }, perform: {})
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🚀 Super Jump! 🚀").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! Mega Jump!") {
                                    card.markSeen(correct: true)
                                    velocity = bounceForce * 1.8
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
                        Text("Fell Down!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("\(Int(abs(highestY / 10)))m high").font(.title2).foregroundColor(.cyan)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !flashcardActive {
                            playerX = min(max(value.location.x, 0), geo.size.width)
                        }
                    }
            )
            .onAppear {
                screenSize = geo.size
                playerX = geo.size.width / 2
                playerY = geo.size.height - 100
                generatePlatforms(from: playerY)
                velocity = bounceForce
                startGame()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Sky Jump")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generatePlatforms(from startY: CGFloat) {
        for i in 0..<30 {
            let y = startY - CGFloat(i) * 70 - 50
            let plat = Platform(
                x: CGFloat.random(in: 40...(screenSize.width - 40)),
                y: y,
                width: CGFloat.random(in: 50...80),
                isMoving: i > 5 && Int.random(in: 0...3) == 0,
                isBroken: i > 8 && Int.random(in: 0...5) == 0
            )
            platforms.append(plat)
        }
    }

    private func startGame() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016

            // Horizontal movement
            playerX += tiltX * 200 * dt
            if playerX < 0 { playerX = screenSize.width }
            if playerX > screenSize.width { playerX = 0 }

            // Gravity
            velocity += gravity * dt
            playerY += velocity * dt

            // Track highest point
            if playerY < highestY {
                highestY = playerY
                score = Int(abs(highestY / 10))

                if score % 50 == 0 && score > 0 && !studySet.flashcards.isEmpty {
                    currentFlashcard = studySet.flashcards.randomElement()
                    showAnswer = false
                    flashcardActive = true
                }
            }

            // Camera follows player up
            let targetCam = playerY - screenSize.height * 0.4
            if targetCam < cameraY {
                cameraY = targetCam
            }

            // Fell below screen
            if playerY - cameraY > screenSize.height + 50 {
                gameOver = true
                timer?.invalidate()
                return
            }

            // Move moving platforms
            for i in platforms.indices {
                if platforms[i].isMoving {
                    platforms[i].x += platforms[i].moveDir * 80 * dt
                    if platforms[i].x > screenSize.width - 30 { platforms[i].moveDir = -1 }
                    if platforms[i].x < 30 { platforms[i].moveDir = 1 }
                }
            }

            // Platform collision (only when falling)
            if velocity > 0 {
                for i in platforms.indices {
                    let plat = platforms[i]
                    let screenPlatY = plat.y
                    if playerY + playerSize / 2 >= screenPlatY - 6 &&
                       playerY + playerSize / 2 <= screenPlatY + 12 &&
                       playerX >= plat.x - plat.width / 2 &&
                       playerX <= plat.x + plat.width / 2 {
                        if plat.isBroken {
                            platforms.remove(at: i)
                        } else {
                            velocity = bounceForce
                        }
                        break
                    }
                }
            }

            // Generate more platforms above
            if let highest = platforms.min(by: { $0.y < $1.y }) {
                if highest.y > cameraY - 100 {
                    generatePlatforms(from: highest.y - 50)
                }
            }

            // Cleanup platforms far below
            platforms.removeAll { $0.y > cameraY + screenSize.height + 200 }
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}
