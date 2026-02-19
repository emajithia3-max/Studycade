import SwiftUI

struct WoodFitGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board: [[Bool]] = Array(repeating: Array(repeating: false, count: 9), count: 9)
    @State private var pieces: [WoodPiece] = []
    @State private var score = 0
    @State private var linesCleared = 0
    @State private var gameOver = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var highlightCells: Set<String> = []

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let cellSize: CGFloat = 36
    private let colors: [Color] = [.brown, .orange.opacity(0.8), Color(red: 0.6, green: 0.4, blue: 0.2)]

    private let shapes: [[(Int, Int)]] = [
        [(0,0)],
        [(0,0),(0,1)],
        [(0,0),(1,0)],
        [(0,0),(0,1),(0,2)],
        [(0,0),(1,0),(2,0)],
        [(0,0),(0,1),(1,0)],
        [(0,0),(0,1),(1,1)],
        [(0,0),(0,1),(1,0),(1,1)],
        [(0,0),(0,1),(0,2),(1,0)],
        [(0,0),(0,1),(0,2),(0,3),(0,4)],
        [(0,0),(1,0),(2,0),(3,0),(4,0)],
        [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)],
    ]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.12, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("Lines: \(linesCleared)")
                        .font(.headline).foregroundColor(.orange)
                }
                .padding(.horizontal, 20)

                // Board
                VStack(spacing: 1) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<9, id: \.self) { col in
                                let filled = board[row][col]
                                let highlighted = highlightCells.contains("\(row),\(col)")
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(filled ?
                                        Color.brown.opacity(0.8) :
                                        (highlighted ? Color.orange.opacity(0.3) : Color.black.opacity(0.2))
                                    )
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        filled ?
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.brown.opacity(0.4), lineWidth: 1) : nil
                                    )
                            }
                        }
                    }
                }
                .padding(6)
                .background(Color(red: 0.25, green: 0.2, blue: 0.15))
                .cornerRadius(8)

                // Pieces
                HStack(spacing: 20) {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { index, piece in
                        if !piece.placed {
                            pieceView(piece)
                                .onTapGesture { placePiece(index: index) }
                        } else {
                            Color.clear.frame(width: 50, height: 50)
                        }
                    }
                }
                .padding()
                .frame(height: 90)

                Text("Tap a piece to auto-place")
                    .font(.caption).foregroundColor(.gray)

                Spacer()
            }
            .padding(.top, 8)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🪵 Clear Bonus! 🪵").font(.headline).foregroundColor(.yellow)
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
                                score += 100
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
                    Text("No Room Left!").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { generatePieces() }
        .navigationTitle("Wood Fit")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func pieceView(_ piece: WoodPiece) -> some View {
        let maxR = piece.cells.map(\.0).max()! + 1
        let maxC = piece.cells.map(\.1).max()! + 1
        let small: CGFloat = 12
        VStack(spacing: 1) {
            ForEach(0..<maxR, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<maxC, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(piece.cells.contains(where: { $0.0 == r && $0.1 == c }) ? Color.brown : Color.clear)
                            .frame(width: small, height: small)
                    }
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }

    private func generatePieces() {
        pieces = (0..<3).map { _ in
            WoodPiece(cells: shapes.randomElement()!, placed: false)
        }
        if !canPlaceAnyPiece() { gameOver = true }
    }

    private func placePiece(index: Int) {
        guard !gameOver && !flashcardActive else { return }
        guard index < pieces.count && !pieces[index].placed else { return }
        let piece = pieces[index]

        for r in 0..<9 {
            for c in 0..<9 {
                if canPlace(piece.cells, at: r, c) {
                    for cell in piece.cells {
                        board[r + cell.0][c + cell.1] = true
                    }
                    pieces[index].placed = true
                    score += piece.cells.count * 5
                    clearLines()

                    if pieces.allSatisfy({ $0.placed }) {
                        generatePieces()
                    } else if !canPlaceAnyPiece() {
                        gameOver = true
                    }
                    return
                }
            }
        }
    }

    private func canPlace(_ cells: [(Int, Int)], at row: Int, _ col: Int) -> Bool {
        for cell in cells {
            let r = row + cell.0, c = col + cell.1
            if r < 0 || r >= 9 || c < 0 || c >= 9 || board[r][c] { return false }
        }
        return true
    }

    private func canPlaceAnyPiece() -> Bool {
        for piece in pieces where !piece.placed {
            for r in 0..<9 {
                for c in 0..<9 {
                    if canPlace(piece.cells, at: r, c) { return true }
                }
            }
        }
        return false
    }

    private func clearLines() {
        var cleared = 0
        for r in 0..<9 {
            if board[r].allSatisfy({ $0 }) {
                board[r] = Array(repeating: false, count: 9)
                cleared += 1
            }
        }
        for c in 0..<9 {
            if (0..<9).allSatisfy({ board[$0][c] }) {
                for r in 0..<9 { board[r][c] = false }
                cleared += 1
            }
        }
        if cleared > 0 {
            let bonus = cleared * cleared * 50
            score += bonus
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

private struct WoodPiece {
    let cells: [(Int, Int)]
    var placed: Bool
}
