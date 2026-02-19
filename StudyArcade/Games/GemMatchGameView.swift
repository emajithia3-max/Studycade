import SwiftUI

struct GemMatchGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var grid: [[Int]] = []
    @State private var selected: (Int, Int)?
    @State private var score = 0
    @State private var movesLeft = 30
    @State private var gameOver = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let rows = 7
    private let cols = 6
    private let gemColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
    private let gemEmojis = ["💎", "🔵", "🟢", "⭐", "🟣", "🔶"]
    private let cellSize: CGFloat = 48

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple.opacity(0.5), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("Moves: \(movesLeft)")
                        .font(.title3).foregroundColor(movesLeft < 5 ? .red : .cyan)
                }
                .padding(.horizontal, 20)

                // Grid
                VStack(spacing: 3) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<cols, id: \.self) { col in
                                let isSelected = selected?.0 == row && selected?.1 == col
                                let val = row < grid.count && col < grid[row].count ? grid[row][col] : 0
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(gemColors[val % gemColors.count].opacity(0.8))
                                        .frame(width: cellSize, height: cellSize)
                                    Text(gemEmojis[val % gemEmojis.count])
                                        .font(.system(size: 24))
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                                )
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.spring(response: 0.2), value: isSelected)
                                .onTapGesture { handleTap(row: row, col: col) }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)

                Spacer()
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("💎 Extra Moves! 💎").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +3 Moves") {
                                card.markSeen(correct: true)
                                movesLeft += 3
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
                    Text("No Moves Left").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { setupGrid() }
        .navigationTitle("Gem Match")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setupGrid() {
        grid = (0..<rows).map { _ in (0..<cols).map { _ in Int.random(in: 0..<gemColors.count) } }
        // Clear initial matches
        resolveMatches()
    }

    private func handleTap(row: Int, col: Int) {
        guard !gameOver && !flashcardActive else { return }
        if let sel = selected {
            let dr = abs(sel.0 - row)
            let dc = abs(sel.1 - col)
            if (dr == 1 && dc == 0) || (dr == 0 && dc == 1) {
                // Swap
                let temp = grid[sel.0][sel.1]
                grid[sel.0][sel.1] = grid[row][col]
                grid[row][col] = temp

                let matched = resolveMatches()
                if !matched {
                    // Swap back
                    let temp2 = grid[sel.0][sel.1]
                    grid[sel.0][sel.1] = grid[row][col]
                    grid[row][col] = temp2
                } else {
                    movesLeft -= 1
                    if movesLeft <= 0 { gameOver = true }
                }
            }
            selected = nil
        } else {
            selected = (row, col)
        }
    }

    @discardableResult
    private func resolveMatches() -> Bool {
        var matched = false
        var toRemove: Set<String> = []

        // Horizontal matches
        for r in 0..<rows {
            var run = 1
            for c in 1..<cols {
                if grid[r][c] == grid[r][c - 1] {
                    run += 1
                } else {
                    if run >= 3 {
                        for i in (c - run)..<c { toRemove.insert("\(r),\(i)") }
                    }
                    run = 1
                }
            }
            if run >= 3 {
                for i in (cols - run)..<cols { toRemove.insert("\(r),\(i)") }
            }
        }

        // Vertical matches
        for c in 0..<cols {
            var run = 1
            for r in 1..<rows {
                if grid[r][c] == grid[r - 1][c] {
                    run += 1
                } else {
                    if run >= 3 {
                        for i in (r - run)..<r { toRemove.insert("\(i),\(c)") }
                    }
                    run = 1
                }
            }
            if run >= 3 {
                for i in (rows - run)..<rows { toRemove.insert("\(i),\(c)") }
            }
        }

        if !toRemove.isEmpty {
            matched = true
            let points = toRemove.count * 15
            score += points

            for key in toRemove {
                let parts = key.split(separator: ",")
                let r = Int(parts[0])!
                let c = Int(parts[1])!
                grid[r][c] = -1
            }

            // Drop and fill
            for c in 0..<cols {
                var writeRow = rows - 1
                for r in stride(from: rows - 1, through: 0, by: -1) {
                    if grid[r][c] != -1 {
                        grid[writeRow][c] = grid[r][c]
                        if writeRow != r { grid[r][c] = -1 }
                        writeRow -= 1
                    }
                }
                for r in 0...writeRow {
                    grid[r][c] = Int.random(in: 0..<gemColors.count)
                }
            }

            // Cascade
            resolveMatches()

            if points >= 45 && !studySet.flashcards.isEmpty && Int.random(in: 0...2) == 0 {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }

        return matched
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
