import SwiftUI

struct PongRallyGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = CGPoint(x: 200, y: 200)
    @State private var playerY: CGFloat = 0
    @State private var cpuY: CGFloat = 0
    @State private var playerScore = 0
    @State private var cpuScore = 0
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var rally = 0
    @State private var maxRally = 0
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let paddleW: CGFloat = 14
    private let paddleH: CGFloat = 80
    private let ballSize: CGFloat = 14

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Center line
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 2, height: 12)
                        .position(x: geo.size.width / 2, y: CGFloat(i) * (geo.size.height / 20) + 10)
                }

                // Score display
                HStack {
                    Text("\(playerScore)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white.opacity(0.15))
                    Spacer()
                    Text("\(cpuScore)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white.opacity(0.15))
                }
                .padding(.horizontal, 60)

                // Player paddle (left)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan)
                    .frame(width: paddleW, height: paddleH)
                    .shadow(color: .cyan, radius: 6)
                    .position(x: 30, y: playerY)

                // CPU paddle (right)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red)
                    .frame(width: paddleW, height: paddleH)
                    .shadow(color: .red, radius: 6)
                    .position(x: geo.size.width - 30, y: cpuY)

                // Ball
                Circle()
                    .fill(Color.white)
                    .frame(width: ballSize, height: ballSize)
                    .shadow(color: .white, radius: 6)
                    .position(ballPos)

                // Rally counter
                if rally > 3 {
                    VStack {
                        Spacer()
                        Text("Rally: \(rally) 🔥")
                            .font(.headline).foregroundColor(.yellow)
                            .padding(.bottom, 30)
                    }
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🏓 Paddle Boost! 🏓").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! +3pts") {
                                    card.markSeen(correct: true)
                                    playerScore += 3
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
                        Text(playerScore >= 7 ? "You Win!" : "CPU Wins")
                            .font(.largeTitle).bold().foregroundColor(.white)
                        Text("\(playerScore) - \(cpuScore)")
                            .font(.title).foregroundColor(.yellow)
                        Text("Best Rally: \(maxRally)")
                            .font(.headline).foregroundColor(.cyan)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !flashcardActive {
                            playerY = min(max(value.location.y, paddleH / 2), geo.size.height - paddleH / 2)
                        }
                    }
            )
            .onAppear {
                screenSize = geo.size
                playerY = geo.size.height / 2
                cpuY = geo.size.height / 2
                resetBall()
                startGame()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Pong Rally")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resetBall() {
        ballPos = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        let angle = CGFloat.random(in: -0.5...0.5)
        let speed: CGFloat = 250
        let dir: CGFloat = Bool.random() ? 1 : -1
        ballVel = CGPoint(x: dir * speed * cos(angle), y: speed * sin(angle))
        rally = 0
    }

    private func startGame() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016

            ballPos.x += ballVel.x * dt
            ballPos.y += ballVel.y * dt

            // Top/bottom bounce
            if ballPos.y <= ballSize / 2 || ballPos.y >= screenSize.height - ballSize / 2 {
                ballVel.y *= -1
            }

            // CPU AI
            let cpuSpeed: CGFloat = 200
            let diff = ballPos.y - cpuY
            cpuY += min(abs(diff), cpuSpeed * dt) * (diff > 0 ? 1 : -1)

            // Player paddle hit
            if ballPos.x - ballSize / 2 <= 30 + paddleW / 2 &&
               ballPos.y >= playerY - paddleH / 2 &&
               ballPos.y <= playerY + paddleH / 2 &&
               ballVel.x < 0 {
                ballVel.x = abs(ballVel.x) * 1.05
                let offset = (ballPos.y - playerY) / (paddleH / 2)
                ballVel.y = offset * 300
                rally += 1
                maxRally = max(maxRally, rally)
            }

            // CPU paddle hit
            if ballPos.x + ballSize / 2 >= screenSize.width - 30 - paddleW / 2 &&
               ballPos.y >= cpuY - paddleH / 2 &&
               ballPos.y <= cpuY + paddleH / 2 &&
               ballVel.x > 0 {
                ballVel.x = -abs(ballVel.x) * 1.05
                let offset = (ballPos.y - cpuY) / (paddleH / 2)
                ballVel.y = offset * 300
                rally += 1
            }

            // Score
            if ballPos.x < -10 {
                cpuScore += 1
                checkGameEnd()
                resetBall()
            } else if ballPos.x > screenSize.width + 10 {
                playerScore += 1

                if playerScore % 3 == 0 && !studySet.flashcards.isEmpty {
                    currentFlashcard = studySet.flashcards.randomElement()
                    showAnswer = false
                    flashcardActive = true
                }

                checkGameEnd()
                resetBall()
            }
        }
    }

    private func checkGameEnd() {
        if playerScore >= 7 || cpuScore >= 7 {
            gameOver = true
            timer?.invalidate()
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(playerScore * 20 + maxRally * 5)
        dismiss()
    }
}
