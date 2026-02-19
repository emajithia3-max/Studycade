import SwiftUI

private struct Mole: Identifiable {
    let id: Int
    var isUp = false
    var isGolden = false
    var hitTimer: Double = 0
}

struct MoleSmashGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var score = 0
    @State private var timeRemaining = 45
    @State private var moles: [Mole] = (0..<9).map { Mole(id: $0) }
    @State private var gameTimer: Timer?
    @State private var spawnTimer: Timer?
    @State private var gameOver = false
    @State private var combo = 0
    @State private var showCombo = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false

    let studySet: StudySet
    let onGameEnd: (Int) -> Void

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color(red: 0.2, green: 0.6, blue: 0.2).ignoresSafeArea()

            VStack(spacing: 16) {
                // HUD
                HStack {
                    Text("⏱ \(timeRemaining)s")
                        .font(.title2).bold()
                        .foregroundColor(timeRemaining < 10 ? .red : .white)
                    Spacer()
                    if showCombo && combo > 1 {
                        Text("🔥 x\(combo)")
                            .font(.title3).bold().foregroundColor(.yellow)
                            .transition(.scale)
                    }
                    Spacer()
                    Text("💰 \(score)")
                        .font(.title2).bold().foregroundColor(.yellow)
                }
                .padding(.horizontal, 20)

                Spacer()

                // 3x3 Mole Grid
                VStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 20) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                moleHole(moles[index])
                            }
                        }
                    }
                }
                .padding(20)

                Spacer()
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🔨 Hammer Boost! 🔨").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +5s") {
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
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Time's Up!").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { startGame() }
        .onDisappear { stopTimers() }
        .navigationTitle("Mole Smash")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func moleHole(_ mole: Mole) -> some View {
        ZStack {
            // Hole
            Ellipse()
                .fill(Color.brown.opacity(0.7))
                .frame(width: 90, height: 40)
                .offset(y: 25)

            // Mole
            if mole.isUp {
                ZStack {
                    Circle()
                        .fill(mole.isGolden ? Color.yellow : Color.brown)
                        .frame(width: 70, height: 70)
                    Text(mole.isGolden ? "👑" : "🐹")
                        .font(.system(size: 36))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { whackMole(mole) }
            }
        }
        .frame(width: 90, height: 80)
        .animation(.spring(response: 0.3), value: mole.isUp)
    }

    private func whackMole(_ mole: Mole) {
        guard let idx = moles.firstIndex(where: { $0.id == mole.id && $0.isUp }) else { return }
        let points = moles[idx].isGolden ? 50 : 10
        combo += 1
        score += points * (combo > 3 ? 2 : 1)
        withAnimation(.spring()) { showCombo = combo > 1 }
        withAnimation { moles[idx].isUp = false }
    }

    private func startGame() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard !flashcardActive else { return }
            timeRemaining -= 1
            if timeRemaining <= 0 {
                gameOver = true
                stopTimers()
            }
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }

            // Hide old moles
            for i in moles.indices {
                if moles[i].isUp {
                    moles[i].hitTimer += 0.6
                    if moles[i].hitTimer > 1.2 {
                        withAnimation { moles[i].isUp = false }
                        combo = 0
                        withAnimation { showCombo = false }
                    }
                }
            }

            // Spawn new moles
            let downMoles = moles.indices.filter { !moles[$0].isUp }
            if let idx = downMoles.randomElement() {
                moles[idx].isUp = true
                moles[idx].hitTimer = 0
                moles[idx].isGolden = Int.random(in: 0...7) == 0
            }

            // Flashcard chance
            if Int.random(in: 0...15) == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func resumeFromFlashcard(bonus: Bool) {
        if bonus { timeRemaining += 5 }
        flashcardActive = false
    }

    private func stopTimers() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
    }

    private func endGame() {
        stopTimers()
        onGameEnd(score)
        dismiss()
    }
}
