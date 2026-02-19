import SwiftUI

struct CardClimberGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var deck: [Int] = []
    @State private var currentCard = 0
    @State private var score = 0
    @State private var streak = 0
    @State private var lives = 3
    @State private var gameOver = false
    @State private var lastGuess: String?
    @State private var showResult = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var cardsPlayed = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let suits = ["♠️", "♥️", "♦️", "♣️"]
    private let values = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    private func cardName(_ value: Int) -> String {
        values[value % 13]
    }

    private func cardSuit(_ value: Int) -> String {
        suits[value / 13]
    }

    private func cardColor(_ value: Int) -> Color {
        let suit = value / 13
        return suit == 1 || suit == 2 ? .red : .white
    }

    var body: some View {
        ZStack {
            Color(red: 0.0, green: 0.3, blue: 0.15).ignoresSafeArea()

            VStack(spacing: 24) {
                // HUD
                HStack {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < lives ? "heart.fill" : "heart")
                                .foregroundColor(.red).font(.title3)
                        }
                    }
                    Spacer()
                    if streak > 1 {
                        Text("🔥 \(streak)x")
                            .font(.headline).foregroundColor(.yellow)
                    }
                    Spacer()
                    Text("Score: \(score)")
                        .font(.title2).bold().foregroundColor(.yellow)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Current card
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 140, height: 200)
                        .shadow(color: .black.opacity(0.3), radius: 8)

                    VStack {
                        HStack {
                            Text(cardName(currentCard))
                                .font(.title).bold()
                            Text(cardSuit(currentCard))
                                .font(.title)
                        }
                        .foregroundColor(cardColor(currentCard))
                    }
                }

                if showResult, let guess = lastGuess {
                    let nextCard = deck.first ?? 0
                    let nextVal = nextCard % 13
                    let currentVal = currentCard % 13
                    let wasCorrect = (guess == "higher" && nextVal >= currentVal) ||
                                     (guess == "lower" && nextVal <= currentVal)
                    Text(wasCorrect ? "✅ Correct!" : "❌ Wrong! It was \(cardName(nextCard)) \(cardSuit(nextCard))")
                        .font(.headline)
                        .foregroundColor(wasCorrect ? .green : .red)
                        .transition(.scale)
                }

                Text("Cards left: \(deck.count)")
                    .font(.caption).foregroundColor(.white.opacity(0.6))

                // Buttons
                HStack(spacing: 30) {
                    Button {
                        guess("lower")
                    } label: {
                        VStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 50))
                            Text("Lower")
                                .font(.headline)
                        }
                        .foregroundColor(.blue)
                        .frame(width: 100)
                    }
                    .disabled(showResult || gameOver)

                    Button {
                        guess("higher")
                    } label: {
                        VStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 50))
                            Text("Higher")
                                .font(.headline)
                        }
                        .foregroundColor(.red)
                        .frame(width: 100)
                    }
                    .disabled(showResult || gameOver)
                }

                Spacer()
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🃏 Peek Bonus! 🃏").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +❤️") {
                                card.markSeen(correct: true)
                                lives = min(lives + 1, 3)
                                score += 25
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
                    Text(lives > 0 ? "Deck Complete!" : "Out of Lives")
                        .font(.largeTitle).bold().foregroundColor(.white)
                    Text("\(cardsPlayed) cards played").font(.title2).foregroundColor(.white)
                    Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .onAppear { setupDeck() }
        .navigationTitle("Card Climber")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setupDeck() {
        deck = Array(0..<52).shuffled()
        currentCard = deck.removeFirst()
    }

    private func guess(_ direction: String) {
        guard !deck.isEmpty else { return }
        lastGuess = direction

        let nextCard = deck.first!
        let nextVal = nextCard % 13
        let currentVal = currentCard % 13

        let correct = (direction == "higher" && nextVal >= currentVal) ||
                       (direction == "lower" && nextVal <= currentVal)

        withAnimation { showResult = true }

        if correct {
            streak += 1
            score += 10 * streak
        } else {
            streak = 0
            lives -= 1
            if lives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { gameOver = true }
                return
            }
        }

        cardsPlayed += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showResult = false
            currentCard = deck.removeFirst()

            if deck.isEmpty {
                gameOver = true
                return
            }

            if cardsPlayed % 8 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                self.showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}
