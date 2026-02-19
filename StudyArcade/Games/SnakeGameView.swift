import SwiftUI

struct SnakeGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var snake: [(Int, Int)] = [(10, 10), (10, 9), (10, 8)]
    @State private var food: (Int, Int) = (5, 5)
    @State private var direction: (Int, Int) = (0, 1)
    @State private var score = 0
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var speed: TimeInterval = 0.15
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let gridSize = 20
    private let cellSize: CGFloat = 17

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("🐍 \(snake.count)")
                        .font(.headline).foregroundColor(.green)
                }
                .padding(.horizontal, 20)

                // Game Grid
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: CGFloat(gridSize) * cellSize, height: CGFloat(gridSize) * cellSize)

                    // Food
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: cellSize - 2, height: cellSize - 2)
                        .position(
                            x: CGFloat(food.1) * cellSize + cellSize / 2,
                            y: CGFloat(food.0) * cellSize + cellSize / 2
                        )

                    // Snake
                    ForEach(Array(snake.enumerated()), id: \.offset) { index, segment in
                        RoundedRectangle(cornerRadius: index == 0 ? 5 : 3)
                            .fill(index == 0 ? Color.green : Color.green.opacity(0.7))
                            .frame(width: cellSize - 1, height: cellSize - 1)
                            .position(
                                x: CGFloat(segment.1) * cellSize + cellSize / 2,
                                y: CGFloat(segment.0) * cellSize + cellSize / 2
                            )
                    }
                }
                .frame(width: CGFloat(gridSize) * cellSize, height: CGFloat(gridSize) * cellSize)
                .border(Color.green.opacity(0.3), width: 1)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            guard !flashcardActive else { return }
                            let h = value.translation.width
                            let v = value.translation.height
                            if abs(h) > abs(v) {
                                if h > 0 && direction != (0, -1) { direction = (0, 1) }
                                else if h < 0 && direction != (0, 1) { direction = (0, -1) }
                            } else {
                                if v > 0 && direction != (-1, 0) { direction = (1, 0) }
                                else if v < 0 && direction != (1, 0) { direction = (-1, 0) }
                            }
                        }
                )

                // D-pad for backup controls
                VStack(spacing: 0) {
                    Button { if direction != (1, 0) { direction = (-1, 0) } } label: {
                        Image(systemName: "chevron.up").font(.title2).frame(width: 60, height: 40)
                    }
                    HStack(spacing: 30) {
                        Button { if direction != (0, 1) { direction = (0, -1) } } label: {
                            Image(systemName: "chevron.left").font(.title2).frame(width: 40, height: 40)
                        }
                        Button { if direction != (0, -1) { direction = (0, 1) } } label: {
                            Image(systemName: "chevron.right").font(.title2).frame(width: 40, height: 40)
                        }
                    }
                    Button { if direction != (-1, 0) { direction = (1, 0) } } label: {
                        Image(systemName: "chevron.down").font(.title2).frame(width: 60, height: 40)
                    }
                }
                .foregroundColor(.green)

                Spacer()
            }
            .padding(.top, 8)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🐍 Growth Boost! 🐍").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +30") {
                                card.markSeen(correct: true)
                                score += 30
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
                    Text("Game Over").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { startGame() }
        .onDisappear { timer?.invalidate() }
        .navigationTitle("Snake Munch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame() {
        spawnFood()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            moveSnake()
        }
    }

    private func moveSnake() {
        let head = snake[0]
        let newHead = (head.0 + direction.0, head.1 + direction.1)

        // Wall collision
        if newHead.0 < 0 || newHead.0 >= gridSize || newHead.1 < 0 || newHead.1 >= gridSize {
            gameOver = true
            timer?.invalidate()
            return
        }

        // Self collision
        if snake.contains(where: { $0.0 == newHead.0 && $0.1 == newHead.1 }) {
            gameOver = true
            timer?.invalidate()
            return
        }

        snake.insert(newHead, at: 0)

        if newHead.0 == food.0 && newHead.1 == food.1 {
            score += 10
            spawnFood()
            if speed > 0.08 { speed -= 0.003; startTimer() }

            if score % 50 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        } else {
            snake.removeLast()
        }
    }

    private func spawnFood() {
        var pos: (Int, Int)
        repeat {
            pos = (Int.random(in: 0..<gridSize), Int.random(in: 0..<gridSize))
        } while snake.contains(where: { $0.0 == pos.0 && $0.1 == pos.1 })
        food = pos
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}
