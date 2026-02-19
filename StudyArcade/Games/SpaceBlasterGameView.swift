import SwiftUI

private struct Enemy: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let speed: CGFloat
    let emoji: String
    var hp: Int
}

private struct Bullet: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
}

struct SpaceBlasterGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shipX: CGFloat = 0
    @State private var enemies: [Enemy] = []
    @State private var bullets: [Bullet] = []
    @State private var score = 0
    @State private var lives = 3
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var spawnTimer: Timer?
    @State private var lastShot: Date = .distantPast
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var wave = 1

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let shipSize: CGFloat = 40
    private let enemyEmojis = ["👾", "🛸", "👽", "🤖", "💀"]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // Stars
                ForEach(0..<30, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.2...0.6)))
                        .frame(width: CGFloat.random(in: 1...2.5))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }

                // Bullets
                ForEach(bullets) { bullet in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.cyan)
                        .frame(width: 4, height: 14)
                        .shadow(color: .cyan, radius: 4)
                        .position(x: bullet.x, y: bullet.y)
                }

                // Enemies
                ForEach(enemies) { enemy in
                    Text(enemy.emoji)
                        .font(.system(size: 32))
                        .position(x: enemy.x, y: enemy.y)
                }

                // Ship
                Text("🚀")
                    .font(.system(size: shipSize))
                    .position(x: shipX, y: geo.size.height - 80)

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
                        Text("Wave \(wave)").font(.headline).foregroundColor(.cyan)
                        Spacer()
                        Text("\(score)")
                            .font(.title).bold().foregroundColor(.white)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🚀 Shield Boost! 🚀").font(.headline).foregroundColor(.yellow)
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
                        Text("Mission Over").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Wave \(wave) • Score: \(score)").font(.title2).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !flashcardActive {
                            shipX = min(max(value.location.x, 20), geo.size.width - 20)
                        }
                    }
            )
            .onTapGesture { location in
                if !gameOver && !flashcardActive { shoot() }
            }
            .onAppear {
                screenSize = geo.size
                shipX = geo.size.width / 2
                startGame()
            }
            .onDisappear { stopTimers() }
        }
        .navigationTitle("Space Blaster")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shoot() {
        guard Date().timeIntervalSince(lastShot) > 0.2 else { return }
        lastShot = Date()
        bullets.append(Bullet(x: shipX, y: screenSize.height - 100))
    }

    private func startGame() {
        // Auto-fire + physics
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }

            // Auto-fire
            if Date().timeIntervalSince(lastShot) > 0.3 {
                shoot()
            }

            // Move bullets
            for i in bullets.indices { bullets[i].y -= 500 * 0.016 }
            bullets.removeAll { $0.y < 0 }

            // Move enemies
            for i in enemies.indices {
                enemies[i].y += enemies[i].speed * 0.016
            }

            // Collision: bullet vs enemy
            for bi in bullets.indices.reversed() {
                for ei in enemies.indices.reversed() {
                    guard bi < bullets.count && ei < enemies.count else { continue }
                    let dist = hypot(bullets[bi].x - enemies[ei].x, bullets[bi].y - enemies[ei].y)
                    if dist < 25 {
                        enemies[ei].hp -= 1
                        bullets.remove(at: bi)
                        if enemies[ei].hp <= 0 {
                            score += 20
                            enemies.remove(at: ei)
                        }
                        break
                    }
                }
            }

            // Enemy reaches bottom
            for i in enemies.indices.reversed() {
                if enemies[i].y > screenSize.height - 60 {
                    lives -= 1
                    enemies.remove(at: i)
                    if lives <= 0 {
                        gameOver = true
                        stopTimers()
                    }
                }
            }
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let count = min(wave, 3)
            for _ in 0..<count {
                let enemy = Enemy(
                    x: CGFloat.random(in: 30...(screenSize.width - 30)),
                    y: -20,
                    speed: CGFloat.random(in: 60...100) + CGFloat(wave) * 10,
                    emoji: enemyEmojis.randomElement()!,
                    hp: wave > 3 ? 2 : 1
                )
                enemies.append(enemy)
            }

            if enemies.isEmpty {
                wave += 1
                if wave % 3 == 0 && !studySet.flashcards.isEmpty {
                    currentFlashcard = studySet.flashcards.randomElement()
                    showAnswer = false
                    flashcardActive = true
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
