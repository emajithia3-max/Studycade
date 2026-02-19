import SwiftUI

private struct Note: Identifiable {
    let id = UUID()
    let lane: Int
    var y: CGFloat
    var hit = false
    var missed = false
}

struct RhythmTapGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [Note] = []
    @State private var score = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var misses = 0
    @State private var gameOver = false
    @State private var timer: Timer?
    @State private var spawnTimer: Timer?
    @State private var screenSize: CGSize = .zero
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var hitEffects: [(Int, Date)] = [] // lane, time
    @State private var totalNotes = 0
    @State private var timeElapsed: Double = 0

    let studySet: StudySet
    let onGameEnd: (Int) -> Void
    private let lanes = 4
    private let hitZoneY: CGFloat = 50 // from bottom
    private let laneColors: [Color] = [.red, .blue, .green, .yellow]
    private let noteSpeed: CGFloat = 300

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        GeometryReader { geo in
            let laneWidth = geo.size.width / CGFloat(lanes)
            let hitY = geo.size.height - hitZoneY

            ZStack {
                Color.black.ignoresSafeArea()

                // Lane dividers
                ForEach(1..<lanes, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: geo.size.height)
                        .position(x: CGFloat(i) * laneWidth, y: geo.size.height / 2)
                }

                // Hit zone line
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: geo.size.width, height: 2)
                    .position(x: geo.size.width / 2, y: hitY)

                // Hit zone buttons
                HStack(spacing: 0) {
                    ForEach(0..<lanes, id: \.self) { lane in
                        Rectangle()
                            .fill(laneColors[lane].opacity(0.15))
                            .frame(width: laneWidth, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(laneColors[lane].opacity(
                                        hitEffects.contains(where: {
                                            $0.0 == lane && Date().timeIntervalSince($0.1) < 0.15
                                        }) ? 0.6 : 0.2
                                    ))
                                    .frame(width: laneWidth - 8, height: 60)
                            )
                            .onTapGesture { tapLane(lane, hitY: hitY) }
                    }
                }
                .position(x: geo.size.width / 2, y: hitY)

                // Falling notes
                ForEach(notes) { note in
                    if !note.hit {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(note.missed ? Color.gray : laneColors[note.lane])
                            .frame(width: laneWidth - 16, height: 30)
                            .shadow(color: laneColors[note.lane].opacity(0.6), radius: note.missed ? 0 : 4)
                            .position(
                                x: CGFloat(note.lane) * laneWidth + laneWidth / 2,
                                y: note.y
                            )
                    }
                }

                // HUD
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Score: \(score)")
                                .font(.title3).bold().foregroundColor(.white)
                            if combo > 2 {
                                Text("🔥 \(combo)x combo")
                                    .font(.caption).foregroundColor(.yellow)
                            }
                        }
                        Spacer()
                        Text("Misses: \(misses)/10")
                            .font(.headline)
                            .foregroundColor(misses > 7 ? .red : .gray)
                    }
                    .padding(.horizontal, 20).padding(.top, 8)
                    Spacer()
                }

                if flashcardActive, let card = currentFlashcard {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("🎵 Rhythm Bonus! 🎵").font(.headline).foregroundColor(.yellow)
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
                                Button("Got it! +Combo") {
                                    card.markSeen(correct: true)
                                    combo += 5
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
                        Text("Song Complete!").font(.largeTitle).bold().foregroundColor(.white)
                        Text("Max Combo: \(maxCombo)x").font(.title2).foregroundColor(.cyan)
                        Text("Score: \(score)").font(.title).foregroundColor(.yellow)
                        Button("Done") { endGame() }
                            .font(.headline)
                            .padding(.horizontal, 40).padding(.vertical, 14)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                    }
                }
            }
            .onAppear {
                screenSize = geo.size
                startGame()
            }
            .onDisappear { stopTimers() }
        }
        .navigationTitle("Rhythm Tap")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tapLane(_ lane: Int, hitY: CGFloat) {
        guard !gameOver && !flashcardActive else { return }
        hitEffects.append((lane, Date()))

        // Find closest note in this lane near hit zone
        if let idx = notes.indices.first(where: {
            notes[$0].lane == lane && !notes[$0].hit && !notes[$0].missed &&
            abs(notes[$0].y - hitY) < 50
        }) {
            notes[idx].hit = true
            combo += 1
            maxCombo = max(maxCombo, combo)
            let points = 10 * min(combo, 8)
            score += points
        } else {
            combo = 0
        }
    }

    private func startGame() {
        // Spawn notes in rhythm patterns
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            timeElapsed += 0.4
            if timeElapsed > 60 { gameOver = true; stopTimers(); return }

            let lane = Int.random(in: 0..<lanes)
            notes.append(Note(lane: lane, y: -20))
            totalNotes += 1

            // Sometimes spawn double notes
            if Int.random(in: 0...3) == 0 {
                let lane2 = (lane + Int.random(in: 1...3)) % lanes
                notes.append(Note(lane: lane2, y: -20))
                totalNotes += 1
            }

            if Int.random(in: 0...20) == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                showAnswer = false
                flashcardActive = true
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            guard !gameOver && !flashcardActive else { return }
            let hitY = screenSize.height - hitZoneY

            for i in notes.indices {
                if !notes[i].hit {
                    notes[i].y += noteSpeed * 0.016
                }
            }

            // Mark misses
            for i in notes.indices {
                if !notes[i].hit && !notes[i].missed && notes[i].y > hitY + 60 {
                    notes[i].missed = true
                    misses += 1
                    combo = 0
                    if misses >= 10 { gameOver = true; stopTimers() }
                }
            }

            // Cleanup
            notes.removeAll { ($0.hit || $0.missed) && $0.y > screenSize.height + 20 }
            hitEffects.removeAll { Date().timeIntervalSince($0.1) > 0.2 }
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
