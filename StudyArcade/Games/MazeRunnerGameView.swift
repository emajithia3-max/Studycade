import SwiftUI

struct MazeRunnerGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var maze: [[Int]] = []
    @State private var playerPos: (Int, Int) = (1, 1)
    @State private var exitPos: (Int, Int) = (1, 1)
    @State private var score = 0
    @State private var level = 1
    @State private var moves = 0
    @State private var gameOver = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var coins: Set<String> = []

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let mazeSize = 13
    private let cellSize: CGFloat = 26

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("Level \(level)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("🪙 \(score)")
                        .font(.title3).foregroundColor(.yellow)
                    Spacer()
                    Text("Moves: \(moves)")
                        .font(.headline).foregroundColor(.gray)
                }
                .padding(.horizontal, 20)

                // Maze grid
                VStack(spacing: 0) {
                    ForEach(0..<mazeSize, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<mazeSize, id: \.self) { col in
                                let isPlayer = playerPos.0 == row && playerPos.1 == col
                                let isExit = exitPos.0 == row && exitPos.1 == col
                                let isWall = row < maze.count && col < maze[row].count && maze[row][col] == 1
                                let hasCoin = coins.contains("\(row),\(col)")

                                ZStack {
                                    Rectangle()
                                        .fill(isWall ? Color.gray.opacity(0.7) : Color.black.opacity(0.3))
                                    if isPlayer {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: cellSize - 6, height: cellSize - 6)
                                            .shadow(color: .cyan, radius: 4)
                                    } else if isExit {
                                        Text("🚪")
                                            .font(.system(size: cellSize * 0.6))
                                    } else if hasCoin {
                                        Text("🪙")
                                            .font(.system(size: cellSize * 0.5))
                                    }
                                }
                                .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                .border(Color.cyan.opacity(0.3), width: 1)

                // D-pad controls
                VStack(spacing: 0) {
                    Button { move(dr: -1, dc: 0) } label: {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 44)).foregroundColor(.cyan)
                    }
                    HStack(spacing: 40) {
                        Button { move(dr: 0, dc: -1) } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 44)).foregroundColor(.cyan)
                        }
                        Button { move(dr: 0, dc: 1) } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 44)).foregroundColor(.cyan)
                        }
                    }
                    Button { move(dr: 1, dc: 0) } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 44)).foregroundColor(.cyan)
                    }
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.top, 8)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🗝️ Maze Key! 🗝️").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +50") {
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
                    Text("Maze Master!").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Completed \(level - 1) mazes").font(.title2).foregroundColor(.cyan)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard !flashcardActive && !gameOver else { return }
                    let h = value.translation.width
                    let v = value.translation.height
                    if abs(h) > abs(v) {
                        move(dr: 0, dc: h > 0 ? 1 : -1)
                    } else {
                        move(dr: v > 0 ? 1 : -1, dc: 0)
                    }
                }
        )
        .onAppear { generateMaze() }
        .navigationTitle("Maze Runner")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func move(dr: Int, dc: Int) {
        guard !gameOver && !flashcardActive else { return }
        let nr = playerPos.0 + dr
        let nc = playerPos.1 + dc
        guard nr >= 0 && nr < mazeSize && nc >= 0 && nc < mazeSize else { return }
        guard maze[nr][nc] == 0 else { return }

        playerPos = (nr, nc)
        moves += 1

        let key = "\(nr),\(nc)"
        if coins.contains(key) {
            coins.remove(key)
            score += 10
        }

        if nr == exitPos.0 && nc == exitPos.1 {
            let bonus = max(100 - moves * 2, 20)
            score += bonus
            level += 1

            if !studySet.flashcards.isEmpty && level % 2 == 0 {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }

            if level > 5 {
                gameOver = true
            } else {
                moves = 0
                generateMaze()
            }
        }
    }

    private func generateMaze() {
        // Simple recursive backtracker maze generation
        maze = Array(repeating: Array(repeating: 1, count: mazeSize), count: mazeSize)
        var visited: Set<String> = []

        func carve(_ r: Int, _ c: Int) {
            visited.insert("\(r),\(c)")
            maze[r][c] = 0
            let dirs = [(0, 2), (0, -2), (2, 0), (-2, 0)].shuffled()
            for (dr, dc) in dirs {
                let nr = r + dr
                let nc = c + dc
                if nr > 0 && nr < mazeSize - 1 && nc > 0 && nc < mazeSize - 1 && !visited.contains("\(nr),\(nc)") {
                    maze[r + dr / 2][c + dc / 2] = 0
                    carve(nr, nc)
                }
            }
        }

        carve(1, 1)
        playerPos = (1, 1)
        exitPos = (mazeSize - 2, mazeSize - 2)
        maze[exitPos.0][exitPos.1] = 0

        // Place coins
        coins.removeAll()
        for r in 1..<mazeSize - 1 {
            for c in 1..<mazeSize - 1 {
                if maze[r][c] == 0 && !(r == 1 && c == 1) && !(r == exitPos.0 && c == exitPos.1) {
                    if Int.random(in: 0...4) == 0 {
                        coins.insert("\(r),\(c)")
                    }
                }
            }
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
