import SwiftUI

struct TileMergeGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
    @State private var score = 0
    @State private var gameOver = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var lastMergeScore = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)

                VStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { col in
                                let val = grid[row][col]
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(tileColor(val))
                                        .aspectRatio(1, contentMode: .fit)
                                    if val > 0 {
                                        Text("\(val)")
                                            .font(.system(size: val >= 1000 ? 18 : val >= 100 ? 22 : 28, weight: .bold))
                                            .foregroundColor(val <= 4 ? .gray : .white)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 16)

                Text("Swipe to merge tiles")
                    .font(.caption).foregroundColor(.gray)

                Spacer()
            }
            .padding(.top, 16)

            // Flashcard overlay
            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🎯 +\(lastMergeScore) Bonus! 🎯").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! x2 Score") {
                                card.markSeen(correct: true)
                                score += lastMergeScore
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
                    Text("No More Moves").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !gameOver && !flashcardActive else { return }
                    let h = value.translation.width
                    let v = value.translation.height
                    if abs(h) > abs(v) {
                        h > 0 ? swipe(.right) : swipe(.left)
                    } else {
                        v > 0 ? swipe(.down) : swipe(.up)
                    }
                }
        )
        .onAppear { spawnTile(); spawnTile() }
        .navigationTitle("Tile Merge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private enum Direction { case up, down, left, right }

    private func swipe(_ dir: Direction) {
        let old = grid
        var mergePoints = 0

        switch dir {
        case .left:
            for r in 0..<4 { let result = mergeLine(grid[r]); grid[r] = result.line; mergePoints += result.points }
        case .right:
            for r in 0..<4 { let result = mergeLine(grid[r].reversed()); grid[r] = result.line.reversed(); mergePoints += result.points }
        case .up:
            for c in 0..<4 {
                let col = (0..<4).map { grid[$0][c] }
                let result = mergeLine(col)
                for r in 0..<4 { grid[r][c] = result.line[r] }
                mergePoints += result.points
            }
        case .down:
            for c in 0..<4 {
                let col = Array((0..<4).map { grid[$0][c] }.reversed())
                let result = mergeLine(col)
                let reversed = Array(result.line.reversed())
                for r in 0..<4 { grid[r][c] = reversed[r] }
                mergePoints += result.points
            }
        }

        if grid != old {
            score += mergePoints
            spawnTile()

            if mergePoints >= 64 && !studySet.flashcards.isEmpty && Int.random(in: 0...2) == 0 {
                lastMergeScore = mergePoints
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }

            if !canMove() { gameOver = true }
        }
    }

    private func mergeLine(_ line: [Int]) -> (line: [Int], points: Int) {
        let filtered = line.filter { $0 != 0 }
        var result: [Int] = []
        var points = 0
        var skip = false
        for i in 0..<filtered.count {
            if skip { skip = false; continue }
            if i + 1 < filtered.count && filtered[i] == filtered[i + 1] {
                let merged = filtered[i] * 2
                result.append(merged)
                points += merged
                skip = true
            } else {
                result.append(filtered[i])
            }
        }
        while result.count < 4 { result.append(0) }
        return (result, points)
    }

    private func spawnTile() {
        var empties: [(Int, Int)] = []
        for r in 0..<4 { for c in 0..<4 { if grid[r][c] == 0 { empties.append((r, c)) } } }
        guard let spot = empties.randomElement() else { return }
        withAnimation(.spring(response: 0.2)) {
            grid[spot.0][spot.1] = Bool.random() ? 2 : (Int.random(in: 0...3) == 0 ? 4 : 2)
        }
    }

    private func canMove() -> Bool {
        for r in 0..<4 {
            for c in 0..<4 {
                if grid[r][c] == 0 { return true }
                if c + 1 < 4 && grid[r][c] == grid[r][c + 1] { return true }
                if r + 1 < 4 && grid[r][c] == grid[r + 1][c] { return true }
            }
        }
        return false
    }

    private func tileColor(_ val: Int) -> Color {
        switch val {
        case 0: return Color.gray.opacity(0.2)
        case 2: return Color(red: 0.93, green: 0.89, blue: 0.85)
        case 4: return Color(red: 0.93, green: 0.88, blue: 0.78)
        case 8: return Color.orange
        case 16: return Color(red: 0.95, green: 0.57, blue: 0.33)
        case 32: return Color.red.opacity(0.8)
        case 64: return Color.red
        case 128: return Color.yellow
        case 256: return Color.yellow.opacity(0.8)
        case 512: return Color(red: 0.93, green: 0.8, blue: 0.0)
        case 1024: return Color(red: 0.93, green: 0.77, blue: 0.0)
        case 2048: return Color(red: 0.93, green: 0.73, blue: 0.0)
        default: return Color.purple
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
