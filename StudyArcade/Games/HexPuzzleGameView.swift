import SwiftUI

struct HexPuzzleGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var grid: [[Int]] = []
    @State private var score = 0
    @State private var pieces: [[HexCell]] = []
    @State private var gameOver = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var linesCleared = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let gridRows = 7
    private let gridCols = 7
    private let hexSize: CGFloat = 30
    private let hexColors: [Color] = [.clear, .cyan, .orange, .green, .pink, .purple, .yellow]

    private let hexShapes: [[(Int, Int)]] = [
        [(0,0)],
        [(0,0),(0,1)],
        [(0,0),(1,0)],
        [(0,0),(0,1),(0,2)],
        [(0,0),(1,0),(2,0)],
        [(0,0),(0,1),(1,0)],
        [(0,0),(0,1),(1,1)],
        [(0,0),(1,0),(1,1)],
    ]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo.opacity(0.3), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("Lines: \(linesCleared)")
                        .font(.headline).foregroundColor(.purple)
                }
                .padding(.horizontal, 20)

                // Hex grid
                VStack(spacing: 3) {
                    ForEach(0..<gridRows, id: \.self) { row in
                        let offset: CGFloat = row % 2 == 1 ? hexSize * 0.55 : 0
                        HStack(spacing: 3) {
                            ForEach(0..<gridCols, id: \.self) { col in
                                let val = row < grid.count && col < grid[row].count ? grid[row][col] : 0
                                Hexagon()
                                    .fill(val > 0 ? hexColors[val % hexColors.count] : Color.gray.opacity(0.15))
                                    .frame(width: hexSize, height: hexSize * 0.87)
                                    .overlay(
                                        Hexagon()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        .offset(x: offset)
                    }
                }
                .padding(12)

                // Piece tray
                HStack(spacing: 20) {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                        if !piece.isEmpty {
                            hexPieceView(piece, colorIndex: index + 1)
                                .onTapGesture { placePieceAuto(index: index) }
                        }
                    }
                }
                .padding()
                .frame(height: 80)

                Text("Tap to place")
                    .font(.caption).foregroundColor(.gray)

                Spacer()
            }
            .padding(.top, 8)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("⬡ Hex Power! ⬡").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +75") {
                                card.markSeen(correct: true)
                                score += 75
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
                    Text("Board Full!").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { setupGrid(); generatePieces() }
        .navigationTitle("Hex Puzzle")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func hexPieceView(_ cells: [HexCell], colorIndex: Int) -> some View {
        let maxR = cells.map(\.r).max()! + 1
        let maxC = cells.map(\.c).max()! + 1
        let small: CGFloat = 14
        VStack(spacing: 1) {
            ForEach(0..<maxR, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<maxC, id: \.self) { c in
                        Hexagon()
                            .fill(cells.contains(where: { $0.r == r && $0.c == c }) ? hexColors[colorIndex % hexColors.count] : Color.clear)
                            .frame(width: small, height: small * 0.87)
                    }
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private func setupGrid() {
        grid = Array(repeating: Array(repeating: 0, count: gridCols), count: gridRows)
    }

    private func generatePieces() {
        pieces = (0..<3).map { _ in
            let shape = hexShapes.randomElement()!
            return shape.map { HexCell(r: $0.0, c: $0.1) }
        }
        if !canPlaceAny() { gameOver = true }
    }

    private func placePieceAuto(index: Int) {
        guard index < pieces.count && !pieces[index].isEmpty else { return }
        let piece = pieces[index]
        let colorVal = index + 1

        for r in 0..<gridRows {
            for c in 0..<gridCols {
                if canPlace(piece, at: r, c) {
                    for cell in piece {
                        grid[r + cell.r][c + cell.c] = colorVal
                    }
                    score += piece.count * 10
                    pieces[index] = []
                    clearRows()

                    if pieces.allSatisfy({ $0.isEmpty }) {
                        generatePieces()
                    } else if !canPlaceAny() {
                        gameOver = true
                    }
                    return
                }
            }
        }
    }

    private func canPlace(_ cells: [HexCell], at row: Int, _ col: Int) -> Bool {
        for cell in cells {
            let r = row + cell.r, c = col + cell.c
            if r < 0 || r >= gridRows || c < 0 || c >= gridCols || grid[r][c] != 0 { return false }
        }
        return true
    }

    private func canPlaceAny() -> Bool {
        for piece in pieces where !piece.isEmpty {
            for r in 0..<gridRows {
                for c in 0..<gridCols {
                    if canPlace(piece, at: r, c) { return true }
                }
            }
        }
        return false
    }

    private func clearRows() {
        var cleared = 0
        for r in 0..<gridRows {
            if grid[r].allSatisfy({ $0 != 0 }) {
                grid[r] = Array(repeating: 0, count: gridCols)
                cleared += 1
            }
        }
        if cleared > 0 {
            score += cleared * cleared * 60
            linesCleared += cleared
            if cleared >= 2 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}

private struct HexCell: Equatable {
    let r: Int
    let c: Int
}

private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let x = cx + w / 2 * cos(angle)
            let y = cy + h / 2 * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}
