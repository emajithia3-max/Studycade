import SwiftUI

struct BrickBreakerGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var paddleX: CGFloat = 0
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = CGPoint(x: 180, y: -250)
    @State private var bricks: [[Bool]] = []
    @State private var score = 0
    @State private var lives = 3
    @State private var gameStarted = false
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let paddleWidth: CGFloat = 90
    private let paddleHeight: CGFloat = 14
    private let ballRadius: CGFloat = 8
    private let brickRows = 5
    private let brickCols = 8

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    private var brickWidth: CGFloat { (screenSize.width - 32) / CGFloat(brickCols) - 4 }
    private let brickHeight: CGFloat = 20
    private var paddleY: CGFloat { screenSize.height - 100 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Bricks
                ForEach(0..<brickRows, id: \.self) { row in
                    ForEach(0..<brickCols, id: \.self) { col in
                        if row < bricks.count && col < bricks[row].count && bricks[row][col] {
                            let hue = Double(row) / Double(brickRows)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hue: hue, saturation: 0.8, brightness: 0.9))
                                .frame(width: brickWidth, height: brickHeight)
                                .position(brickPosition(row: row, col: col))
                        }
                    }
                }

                // Ball
                Circle()
                    .fill(Color.white)
                    .frame(width: ballRadius * 2, height: ballRadius * 2)
                    .shadow(color: .cyan, radius: 6)
                    .position(ballPos)

                // Paddle
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: paddleWidth, height: paddleHeight)
                    .position(x: paddleX, y: paddleY)

                // HUD
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < lives ? "heart.fill" : "heart")
                                    .foregroundColor(.red).font(.title3)
                            }
                        }
                        Spacer()
                        Text("\(score)")
                            .font(.title).bold().foregroundColor(.white)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if !gameStarted && !gameOver {
                    Text("Drag paddle, tap to launch")
                        .font(.headline).foregroundColor(.white)
                        .shadow(color: .black, radius: 4)
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🧱 Extra Life? 🧱").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! +❤️") {
                                    card.markSeen(correct: true)
                                    lives = min(lives + 1, 3)
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
                        Text(bricksRemaining == 0 ? "You Win!" : "Game Over")
                            .font(.largeTitle).bold().foregroundColor(.white)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
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
                            paddleX = min(max(value.location.x, paddleWidth / 2), geo.size.width - paddleWidth / 2)
                            if !gameStarted {
                                ballPos = CGPoint(x: paddleX, y: paddleY - paddleHeight / 2 - ballRadius - 2)
                            }
                        }
                    }
            )
            .onTapGesture {
                if !gameStarted && !gameOver && !flashcardActive {
                    gameStarted = true
                    startGameLoop()
                }
            }
            .onAppear {
                screenSize = geo.size
                paddleX = geo.size.width / 2
                resetBall()
                setupBricks()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Brick Breaker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bricksRemaining: Int {
        bricks.flatMap { $0 }.filter { $0 }.count
    }

    private func brickPosition(row: Int, col: Int) -> CGPoint {
        let totalW = (brickWidth + 4) * CGFloat(brickCols)
        let startX = (screenSize.width - totalW) / 2 + brickWidth / 2 + 2
        let x = startX + CGFloat(col) * (brickWidth + 4)
        let y: CGFloat = 80 + CGFloat(row) * (brickHeight + 4)
        return CGPoint(x: x, y: y)
    }

    private func setupBricks() {
        bricks = Array(repeating: Array(repeating: true, count: brickCols), count: brickRows)
    }

    private func resetBall() {
        ballPos = CGPoint(x: paddleX, y: paddleY - paddleHeight / 2 - ballRadius - 2)
        ballVel = CGPoint(x: CGFloat.random(in: -1...1) > 0 ? 180 : -180, y: -250)
        gameStarted = false
    }

    private func startGameLoop() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && gameStarted && !flashcardActive else { return }
            let dt: CGFloat = 0.016
            ballPos.x += ballVel.x * dt
            ballPos.y += ballVel.y * dt

            // Wall bounce
            if ballPos.x <= ballRadius || ballPos.x >= screenSize.width - ballRadius {
                ballVel.x *= -1
            }
            if ballPos.y <= ballRadius + 40 { ballVel.y = abs(ballVel.y) }

            // Ball fell below paddle
            if ballPos.y > screenSize.height {
                lives -= 1
                if lives <= 0 { gameOver = true; timer?.invalidate() }
                else { resetBall() }
                return
            }

            // Paddle collision
            if ballPos.y + ballRadius >= paddleY - paddleHeight / 2 &&
               ballPos.y - ballRadius <= paddleY + paddleHeight / 2 &&
               ballPos.x >= paddleX - paddleWidth / 2 &&
               ballPos.x <= paddleX + paddleWidth / 2 &&
               ballVel.y > 0 {
                ballVel.y = -abs(ballVel.y)
                let offset = (ballPos.x - paddleX) / (paddleWidth / 2)
                ballVel.x = offset * 250
            }

            // Brick collision
            for row in 0..<brickRows {
                for col in 0..<brickCols {
                    guard row < bricks.count && col < bricks[row].count && bricks[row][col] else { continue }
                    let pos = brickPosition(row: row, col: col)
                    if ballPos.x + ballRadius > pos.x - brickWidth / 2 &&
                       ballPos.x - ballRadius < pos.x + brickWidth / 2 &&
                       ballPos.y + ballRadius > pos.y - brickHeight / 2 &&
                       ballPos.y - ballRadius < pos.y + brickHeight / 2 {
                        bricks[row][col] = false
                        ballVel.y *= -1
                        score += 10 + row * 5

                        if bricksRemaining == 0 {
                            gameOver = true
                            timer?.invalidate()
                        }

                        if bricksRemaining % 10 == 0 && !studySet.flashcards.isEmpty {
                            currentFlashcard = studySet.flashcards.randomElement()
                            showAnswer = false
                            flashcardActive = true
                        }
                        return
                    }
                }
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}
