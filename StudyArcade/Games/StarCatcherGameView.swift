import SwiftUI

private struct FallingItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let speed: CGFloat
    let isStar: Bool // true = star (good), false = bomb (bad)
    let emoji: String
}

struct StarCatcherGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var basketX: CGFloat = 0
    @State private var items: [FallingItem] = []
    @State private var score = 0
    @State private var lives = 3
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var spawnTimer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var combo = 0
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var catchEffect: CGFloat = 1.0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let basketWidth: CGFloat = 80
    private let starEmojis = ["⭐", "🌟", "💫", "✨", "🪙", "💰"]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.black, .indigo.opacity(0.5), .purple.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Stars background
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat(i) * geo.size.width / 20 + CGFloat.random(in: -10...10),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }

                // Falling items
                ForEach(items) { item in
                    Text(item.emoji)
                        .font(.system(size: 32))
                        .position(x: item.x, y: item.y)
                }

                // Basket
                VStack(spacing: 0) {
                    Text("🧺")
                        .font(.system(size: 50))
                        .scaleEffect(catchEffect)
                }
                .position(x: basketX, y: geo.size.height - 80)

                // HUD
                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < lives ? "heart.fill" : "heart")
                                    .foregroundColor(.red).font(.title3)
                            }
                        }
                        Spacer()
                        if combo > 2 {
                            Text("🔥 x\(combo)")
                                .font(.headline).foregroundColor(.yellow)
                        }
                        Spacer()
                        Text("\(score)")
                            .font(.title).bold().foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("⭐ Star Power! ⭐").font(.headline).foregroundColor(.yellow)
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
                        Text("Game Over").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !flashcardActive {
                            basketX = min(max(value.location.x, basketWidth / 2), geo.size.width - basketWidth / 2)
                        }
                    }
            )
            .onAppear {
                screenSize = geo.size
                basketX = geo.size.width / 2
                startGame()
            }
            .onDisappear { stopTimers() }
        }
        .navigationTitle("Star Catcher")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame() {
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let isBomb = Int.random(in: 0...4) == 0
            let item = FallingItem(
                x: CGFloat.random(in: 30...(screenSize.width - 30)),
                y: -20,
                speed: CGFloat.random(in: 150...250) + CGFloat(score / 10) * 5,
                isStar: !isBomb,
                emoji: isBomb ? "💀" : starEmojis.randomElement()!
            )
            items.append(item)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            for i in items.indices {
                items[i].y += items[i].speed * 0.016
            }

            // Check catches
            let catchY = screenSize.height - 80
            for i in items.indices.reversed() {
                if items[i].y >= catchY - 30 && items[i].y <= catchY + 20 {
                    if abs(items[i].x - basketX) < basketWidth / 2 {
                        if items[i].isStar {
                            combo += 1
                            let points = 10 * min(combo, 5)
                            score += points
                            withAnimation(.spring(response: 0.15)) { catchEffect = 1.2 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation { catchEffect = 1.0 }
                            }

                            if score % 100 == 0 && !studySet.flashcards.isEmpty {
                                currentFlashcard = studySet.flashcards.randomElement()
                                showAnswer = false
                                flashcardActive = true
                            }
                        } else {
                            lives -= 1
                            combo = 0
                            if lives <= 0 {
                                gameOver = true
                                stopTimers()
                            }
                        }
                        items.remove(at: i)
                        continue
                    }
                }

                // Missed star falls off screen
                if items[i].y > screenSize.height + 20 {
                    if items[i].isStar { combo = 0 }
                    items.remove(at: i)
                }
            }
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        spawnTimer?.invalidate()
    }

    private func endGame() {
        stopTimers()
        onGameEnd(score)
        dismiss()
    }
}
