import SwiftUI

struct BlockDropGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 8), count: 8)
    @State private var score = 0
    @State private var currentPieces: [[[(Int, Int)]]] = []
    @State private var gameOver = false
    @State private var dragPieceIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var clearedRows = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let cellSize: CGFloat = 38
    private let colors: [Color] = [.clear, .red, .blue, .green, .orange, .purple, .pink, .yellow, .cyan]

    private let shapes: [[(Int, Int)]] = [
        [(0,0)],                                          // dot
        [(0,0),(0,1)],                                    // 2-horizontal
        [(0,0),(1,0)],                                    // 2-vertical
        [(0,0),(0,1),(0,2)],                              // 3-horizontal
        [(0,0),(1,0),(2,0)],                              // 3-vertical
        [(0,0),(0,1),(1,0),(1,1)],                        // 2x2 square
        [(0,0),(0,1),(0,2),(1,0),(1,1),(1,2),(2,0),(2,1),(2,2)], // 3x3 square
        [(0,0),(1,0),(1,1)],                              // L-shape
        [(0,0),(0,1),(1,1)],                              // L-shape rotated
        [(0,0),(0,1),(0,2),(0,3)],                        // 4-horizontal
        [(0,0),(1,0),(2,0),(3,0)],                        // 4-vertical
        [(0,0),(0,1),(0,2),(1,0),(2,0)],                  // big L
    ]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.12, blue: 0.15).ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("Lines: \(clearedRows)")
                        .font(.headline).foregroundColor(.cyan)
                }
                .padding(.horizontal, 20)

                // Board
                VStack(spacing: 1) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<8, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(board[row][col] > 0 ? colors[board[row][col] % colors.count] : Color.gray.opacity(0.15))
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Piece tray
                HStack(spacing: 24) {
                    ForEach(Array(currentPieces.enumerated()), id: \.offset) { index, pieces in
                        if let piece = pieces.first {
                            pieceView(piece, colorIndex: index + 1)
                                .onTapGesture {
                                    placePieceAtBestSpot(index: index)
                                }
                        }
                    }
                }
                .padding()
                .frame(height: 100)

                Text("Tap a piece to place it")
                    .font(.caption).foregroundColor(.gray)
                Spacer()
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("💎 Clear Bonus! 💎").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! x2") {
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
                    Text("No Moves Left").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { generatePieces() }
        .navigationTitle("Block Drop")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func pieceView(_ cells: [(Int, Int)], colorIndex: Int) -> some View {
        let maxR = cells.map(\.0).max()! + 1
        let maxC = cells.map(\.1).max()! + 1
        let small: CGFloat = 14
        VStack(spacing: 1) {
            ForEach(0..<maxR, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<maxC, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cells.contains(where: { $0.0 == r && $0.1 == c }) ? colors[colorIndex % colors.count] : Color.clear)
                            .frame(width: small, height: small)
                    }
                }
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func generatePieces() {
        currentPieces = (0..<3).map { _ in [shapes.randomElement()!] }
        if !canPlaceAny() { gameOver = true }
    }

    private func placePieceAtBestSpot(index: Int) {
        guard index < currentPieces.count, let piece = currentPieces[index].first else { return }
        let colorVal = index + 1

        // Find first valid placement
        for r in 0..<8 {
            for c in 0..<8 {
                if canPlace(piece, at: r, c) {
                    for cell in piece {
                        board[r + cell.0][c + cell.1] = colorVal
                    }
                    score += piece.count * 5
                    currentPieces[index] = []
                    clearLines()

                    if currentPieces.allSatisfy({ $0.isEmpty }) {
                        generatePieces()
                    } else if !canPlaceAny() {
                        gameOver = true
                    }
                    return
                }
            }
        }
    }

    private func canPlace(_ piece: [(Int, Int)], at row: Int, _ col: Int) -> Bool {
        for cell in piece {
            let r = row + cell.0
            let c = col + cell.1
            if r < 0 || r >= 8 || c < 0 || c >= 8 || board[r][c] != 0 { return false }
        }
        return true
    }

    private func canPlaceAny() -> Bool {
        for pieces in currentPieces {
            guard let piece = pieces.first else { continue }
            for r in 0..<8 {
                for c in 0..<8 {
                    if canPlace(piece, at: r, c) { return true }
                }
            }
        }
        return false
    }

    private func clearLines() {
        var cleared = 0
        // Check rows
        for r in 0..<8 {
            if board[r].allSatisfy({ $0 != 0 }) {
                board[r] = Array(repeating: 0, count: 8)
                cleared += 1
            }
        }
        // Check columns
        for c in 0..<8 {
            if (0..<8).allSatisfy({ board[$0][c] != 0 }) {
                for r in 0..<8 { board[r][c] = 0 }
                cleared += 1
            }
        }
        if cleared > 0 {
            let bonus = cleared * cleared * 50
            score += bonus
            clearedRows += cleared

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
