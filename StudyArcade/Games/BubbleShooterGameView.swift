import SwiftUI

private struct Bubble: Identifiable, Equatable {
    let id = UUID()
    var row: Int
    var col: Int
    var color: Int // -1 = empty
    static func == (lhs: Bubble, rhs: Bubble) -> Bool { lhs.id == rhs.id }
}

struct BubbleShooterGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var grid: [[Int]] = []
    @State private var score = 0
    @State private var currentColor = 0
    @State private var nextColor = 1
    @State private var aimAngle: CGFloat = -.pi / 2
    @State private var gameOver = false
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var shotsLeft = 50

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let rows = 10
    private let cols = 8
    private let bubbleSize: CGFloat = 38
    private let bubbleColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()

                VStack(spacing: 8) {
                    HStack {
                        Text("Score: \(score)")
                            .font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        Text("Shots: \(shotsLeft)")
                            .font(.headline).foregroundColor(shotsLeft < 10 ? .red : .cyan)
                    }
                    .padding(.horizontal, 20)

                    // Bubble grid
                    VStack(spacing: 2) {
                        ForEach(0..<rows, id: \.self) { row in
                            let offset: CGFloat = row % 2 == 1 ? bubbleSize / 2 : 0
                            HStack(spacing: 2) {
                                ForEach(0..<cols, id: \.self) { col in
                                    let val = row < grid.count && col < grid[row].count ? grid[row][col] : -1
                                    Circle()
                                        .fill(val >= 0 ? bubbleColors[val % bubbleColors.count] : Color.clear)
                                        .frame(width: bubbleSize - 4, height: bubbleSize - 4)
                                        .overlay(
                                            Circle().stroke(val >= 0 ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                }
                            }
                            .offset(x: offset)
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    // Shooter
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(bubbleColors[nextColor % bubbleColors.count])
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))

                            Circle()
                                .fill(bubbleColors[currentColor % bubbleColors.count])
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: bubbleColors[currentColor % bubbleColors.count], radius: 6)
                        }

                        Text("Tap a column to shoot")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)

                // Tap to shoot at column
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard !gameOver && !flashcardActive else { return }
                        let col = Int(location.x / (geo.size.width / CGFloat(cols)))
                        shootAtColumn(min(max(col, 0), cols - 1))
                    }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🫧 Extra Shots! 🫧").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! +5 Shots") {
                                    card.markSeen(correct: true)
                                    shotsLeft += 5
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
                        let cleared = grid.flatMap { $0 }.filter { $0 == -1 }.count == rows * cols
                        Text(cleared ? "Cleared!" : "Out of Shots").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .onAppear {
                screenSize = geo.size
                setupGrid()
            }
        }
        .navigationTitle("Bubble Shooter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setupGrid() {
        grid = (0..<rows).map { row in
            (0..<cols).map { _ in
                row < 5 ? Int.random(in: 0..<bubbleColors.count) : -1
            }
        }
        currentColor = Int.random(in: 0..<bubbleColors.count)
        nextColor = Int.random(in: 0..<bubbleColors.count)
    }

    private func shootAtColumn(_ col: Int) {
        // Find lowest empty row in that column
        var targetRow = -1
        for r in stride(from: rows - 1, through: 0, by: -1) {
            if grid[r][col] == -1 {
                targetRow = r
                break
            }
        }

        guard targetRow >= 0 else { return }

        grid[targetRow][col] = currentColor
        shotsLeft -= 1

        // Check for matches
        let matched = findMatches(row: targetRow, col: col, color: currentColor)
        if matched.count >= 3 {
            let points = matched.count * 20
            score += points
            for (r, c) in matched {
                grid[r][c] = -1
            }

            if points >= 60 && !studySet.flashcards.isEmpty && Int.random(in: 0...2) == 0 {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }

        currentColor = nextColor
        nextColor = Int.random(in: 0..<bubbleColors.count)

        // Check game over
        let allCleared = grid.flatMap { $0 }.allSatisfy { $0 == -1 }
        if allCleared || shotsLeft <= 0 {
            gameOver = true
        }
    }

    private func findMatches(row: Int, col: Int, color: Int) -> [(Int, Int)] {
        var visited: Set<String> = []
        var result: [(Int, Int)] = []

        func dfs(_ r: Int, _ c: Int) {
            let key = "\(r),\(c)"
            guard !visited.contains(key) else { return }
            guard r >= 0 && r < rows && c >= 0 && c < cols else { return }
            guard grid[r][c] == color else { return }
            visited.insert(key)
            result.append((r, c))
            dfs(r - 1, c); dfs(r + 1, c); dfs(r, c - 1); dfs(r, c + 1)
        }

        dfs(row, col)
        return result
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
