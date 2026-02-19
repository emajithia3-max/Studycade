import SwiftUI

private struct RunnerObstacle: Identifiable {
    let id = UUID()
    let lane: Int
    var y: CGFloat
    let emoji: String
    let isCoin: Bool
}

struct LaneRunnerGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerLane = 1
    @State private var obstacles: [RunnerObstacle] = []
    @State private var score = 0
    @State private var coins = 0
    @State private var lives = 3
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var speed: CGFloat = 250
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var playerScale: CGFloat = 1.0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let laneCount = 3
    private let carEmojis = ["🚗", "🚕", "🚙", "🏎️", "🚓"]
    private let truckEmojis = ["🚛", "🚌", "🚚"]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    private func laneX(_ lane: Int) -> CGFloat {
        let w = screenSize.width / CGFloat(laneCount)
        return w * CGFloat(lane) + w / 2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.gray.opacity(0.3).ignoresSafeArea()

                // Road
                Rectangle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                    .frame(width: geo.size.width * 0.9)

                // Lane dividers
                ForEach(1..<laneCount, id: \.self) { i in
                    let x = geo.size.width * 0.05 + CGFloat(i) * (geo.size.width * 0.9 / CGFloat(laneCount))
                    ForEach(0..<15, id: \.self) { j in
                        Rectangle()
                            .fill(Color.yellow.opacity(0.5))
                            .frame(width: 4, height: 30)
                            .position(x: x, y: CGFloat(j) * 60 + 15)
                    }
                }

                // Obstacles & coins
                ForEach(obstacles) { obs in
                    Text(obs.emoji)
                        .font(.system(size: obs.isCoin ? 28 : 40))
                        .position(x: laneX(obs.lane), y: obs.y)
                }

                // Player
                Text("🏃")
                    .font(.system(size: 44))
                    .scaleEffect(playerScale)
                    .position(x: laneX(playerLane), y: geo.size.height - 120)

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
                        Text("🪙 \(coins)")
                            .font(.headline).foregroundColor(.yellow)
                        Spacer()
                        Text("\(score)m")
                            .font(.title2).bold().foregroundColor(.white)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🏃 Second Wind! 🏃").font(.headline).foregroundColor(.yellow)
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
                        Text("Crashed!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("\(score)m • \(coins) coins").font(.title2).foregroundColor(.yellow)
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
                        if value.translation.width > 30 && playerLane < laneCount - 1 {
                            withAnimation(.spring(response: 0.2)) { playerLane += 1 }
                        } else if value.translation.width < -30 && playerLane > 0 {
                            withAnimation(.spring(response: 0.2)) { playerLane -= 1 }
                        }
                    }
            )
            .onAppear {
                screenSize = geo.size
                startGame()
            }
            .onDisappear { timer?.invalidate() }
        }
        .navigationTitle("Lane Runner")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startGame() {
        var spawnCounter: CGFloat = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let dt: CGFloat = 0.016

            for i in obstacles.indices { obstacles[i].y += speed * dt }

            let playerY = screenSize.height - 120
            for i in obstacles.indices.reversed() {
                if obstacles[i].y > playerY - 25 && obstacles[i].y < playerY + 25 && obstacles[i].lane == playerLane {
                    if obstacles[i].isCoin {
                        coins += 1
                        score += 5
                        withAnimation(.spring(response: 0.1)) { playerScale = 1.15 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { playerScale = 1.0 }
                        }
                    } else {
                        lives -= 1
                        if lives <= 0 {
                            gameOver = true
                            timer?.invalidate()
                            return
                        }
                    }
                    obstacles.remove(at: i)
                    continue
                }
            }

            obstacles.removeAll { $0.y > screenSize.height + 50 }

            spawnCounter += speed * dt
            if spawnCounter > 120 {
                spawnCounter = 0
                let lane = Int.random(in: 0..<laneCount)
                let isCoin = Int.random(in: 0...3) == 0
                let emoji = isCoin ? "🪙" : (Bool.random() ? carEmojis.randomElement()! : truckEmojis.randomElement()!)
                obstacles.append(RunnerObstacle(lane: lane, y: -30, emoji: emoji, isCoin: isCoin))
            }

            score += 1
            speed = min(speed + 0.03, 500)

            if score % 300 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        onGameEnd(score / 10 + coins * 5)
        dismiss()
    }
}
