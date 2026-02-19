import SwiftUI

struct TowerStackGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var score = 0
    @State private var blocks: [CGRect] = []
    @State private var currentBlockX: CGFloat = 0
    @State private var blockDirection: CGFloat = 1
    @State private var blockWidth: CGFloat = 150
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var perfectStreak = 0
    @State private var showPerfect = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var cameraOffset: CGFloat = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let blockHeight: CGFloat = 30

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    private var currentBlockY: CGFloat {
        let baseY = screenSize.height - 60 - CGFloat(blocks.count) * blockHeight
        return baseY - cameraOffset
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.indigo, .purple, .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Stacked blocks
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    let y = screenSize.height - 60 - CGFloat(index) * blockHeight - blockHeight / 2 - cameraOffset
                    let hue = Double(index % 12) / 12.0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hue: hue, saturation: 0.7, brightness: 0.9))
                        .frame(width: block.width, height: blockHeight - 2)
                        .position(x: block.midX, y: y)
                }

                // Moving block
                if !gameOver {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: blockWidth, height: blockHeight - 2)
                        .position(x: currentBlockX, y: currentBlockY - blockHeight / 2)
                        .shadow(color: .white.opacity(0.5), radius: 8)
                }

                // HUD
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        if showPerfect {
                            Text("PERFECT! 🔥\(perfectStreak)")
                                .font(.headline).foregroundColor(.yellow)
                                .transition(.scale)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    Spacer()
                }

                // Flashcard overlay
                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🧱 Bonus Block! 🧱").font(.headline).foregroundColor(.yellow)
                        Text(card.front)
                            .font(.title2).bold().foregroundColor(.white)
                            .multilineTextAlignment(.center).padding()
                        if showAnswer {
                            Text(card.back).font(.title3).foregroundColor(.green).padding()
                            HStack(spacing: 20) {
                                Button("Wrong") {
                                    card.markSeen(correct: false)
                                    resumeFromFlashcard(bonus: false)
                                }
                                .padding(.horizontal, 24).padding(.vertical, 10)
                                .background(Color.red).foregroundColor(.white).cornerRadius(10)
                                Button("Got it! +Width") {
                                    card.markSeen(correct: true)
                                    resumeFromFlashcard(bonus: true)
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
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Tower Complete!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("\(blocks.count) blocks high").font(.title2).foregroundColor(.cyan)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !gameOver && !flashcardActive { dropBlock() } }
            .onAppear {
                screenSize = geo.size
                currentBlockX = geo.size.width / 2
                startMoving()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Tower Stack")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startMoving() {
        let speed: CGFloat = 200 + CGFloat(blocks.count) * 8
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            currentBlockX += blockDirection * speed * 0.016
            if currentBlockX + blockWidth / 2 > screenSize.width {
                blockDirection = -1
            } else if currentBlockX - blockWidth / 2 < 0 {
                blockDirection = 1
            }
        }
    }

    private func dropBlock() {
        let newBlock: CGRect
        if blocks.isEmpty {
            newBlock = CGRect(x: currentBlockX - blockWidth / 2, y: 0, width: blockWidth, height: blockHeight)
        } else {
            let prev = blocks.last!
            let overlapLeft = max(currentBlockX - blockWidth / 2, prev.minX)
            let overlapRight = min(currentBlockX + blockWidth / 2, prev.maxX)
            let overlapWidth = overlapRight - overlapLeft

            if overlapWidth <= 0 {
                gameOver = true
                timer?.invalidate()
                return
            }

            let isPerfect = abs(overlapWidth - prev.width) < 4
            if isPerfect {
                perfectStreak += 1
                score += 20 + perfectStreak * 5
                withAnimation(.spring()) { showPerfect = true }
                newBlock = CGRect(x: prev.minX, y: 0, width: prev.width, height: blockHeight)
            } else {
                perfectStreak = 0
                withAnimation { showPerfect = false }
                score += 10
                blockWidth = overlapWidth
                newBlock = CGRect(x: overlapLeft, y: 0, width: overlapWidth, height: blockHeight)
            }
        }

        blocks.append(newBlock)
        currentBlockX = screenSize.width / 2

        // Camera scroll up after 10 blocks
        if blocks.count > 10 {
            withAnimation(.easeOut(duration: 0.3)) {
                cameraOffset = CGFloat(blocks.count - 10) * blockHeight
            }
        }

        // Restart movement
        timer?.invalidate()
        startMoving()

        // Flashcard every 8 blocks
        if blocks.count % 8 == 0 && !studySet.flashcards.isEmpty {
            flashcardActive = true
            currentFlashcard = studySet.flashcards.randomElement()
            showAnswer = false
        }
    }

    private func resumeFromFlashcard(bonus: Bool) {
        if bonus {
            blockWidth = min(blockWidth + 30, 150)
            score += 30
        }
        flashcardActive = false
        currentFlashcard = nil
        showAnswer = false
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score)
        dismiss()
    }
}
