import SwiftUI

struct PatternPulseGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pattern: [Int] = []
    @State private var playerInput: [Int] = []
    @State private var isShowingPattern = false
    @State private var activeButton: Int?
    @State private var score = 0
    @State private var round = 0
    @State private var gameOver = false
    @State private var canTap = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var message = "Watch the pattern..."

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let colors: [(Color, String)] = [
        (.red, "🔴"), (.blue, "🔵"), (.green, "🟢"), (.yellow, "🟡")
    ]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Round: \(round)")
                        .font(.title2).bold().foregroundColor(.white)
                    Spacer()
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.cyan)
                }
                .padding(.horizontal, 24)

                Text(message)
                    .font(.headline).foregroundColor(.gray)
                    .animation(.easeInOut, value: message)

                Spacer()

                // 4 color buttons in a 2x2 grid
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        colorButton(0)
                        colorButton(1)
                    }
                    HStack(spacing: 20) {
                        colorButton(2)
                        colorButton(3)
                    }
                }

                Spacer()

                // Pattern progress dots
                HStack(spacing: 6) {
                    ForEach(0..<pattern.count, id: \.self) { i in
                        Circle()
                            .fill(i < playerInput.count ? colors[pattern[i]].0 : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🧠 Memory Boost! 🧠").font(.headline).foregroundColor(.yellow)
                    Text(card.front)
                        .font(.title2).bold().foregroundColor(.white)
                        .multilineTextAlignment(.center).padding()
                    if showAnswer {
                        Text(card.back).font(.title3).foregroundColor(.green).padding()
                        HStack(spacing: 20) {
                            Button("Wrong") {
                                card.markSeen(correct: false)
                                flashcardActive = false
                                nextRound()
                            }
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Color.red).foregroundColor(.white).cornerRadius(10)
                            Button("Got it! +50") {
                                card.markSeen(correct: true)
                                score += 50
                                flashcardActive = false
                                nextRound()
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
                    Text("Wrong!").font(.largeTitle).bold().foregroundColor(.red)
                    Text("Reached Round \(round)").font(.title2).foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { nextRound() }
        .navigationTitle("Pattern Pulse")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func colorButton(_ index: Int) -> some View {
        let isActive = activeButton == index
        Button {
            guard canTap && !flashcardActive else { return }
            tapColor(index)
        } label: {
            RoundedRectangle(cornerRadius: 20)
                .fill(colors[index].0.opacity(isActive ? 1.0 : 0.4))
                .frame(width: 130, height: 130)
                .overlay(
                    Text(colors[index].1)
                        .font(.system(size: 40))
                        .opacity(isActive ? 1.0 : 0.6)
                )
                .shadow(color: isActive ? colors[index].0 : .clear, radius: 12)
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.15), value: isActive)
    }

    private func nextRound() {
        round += 1
        pattern.append(Int.random(in: 0..<4))
        playerInput = []
        canTap = false
        message = "Watch the pattern..."
        showPattern()
    }

    private func showPattern() {
        isShowingPattern = true
        for (i, color) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6 + 0.5) {
                activeButton = color
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6 + 0.9) {
                activeButton = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pattern.count) * 0.6 + 1.0) {
            isShowingPattern = false
            canTap = true
            message = "Your turn! Repeat the pattern"
        }
    }

    private func tapColor(_ index: Int) {
        activeButton = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { activeButton = nil }

        playerInput.append(index)
        let pos = playerInput.count - 1

        if pattern[pos] != index {
            gameOver = true
            return
        }

        if playerInput.count == pattern.count {
            let bonus = pattern.count * 10
            score += bonus
            canTap = false
            message = "Correct! 🎉"

            if round % 4 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextRound() }
            }
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
