import SwiftUI
import SwiftData

struct TapGameView: View {
    @State private var score = 0
    @State private var timeRemaining = 60
    @State private var isGameActive = true
    @State private var targets: [TapTarget] = []
    @State private var gameTimer: Timer?
    @State private var injectedFlashcard: Flashcard?

    let studySet: StudySet
    let onGameEnd: (Int) -> Void

    private var gameWrapper: GameWrapper<AnyView>?

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(score)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(timeRemaining)s")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(timeRemaining < 10 ? .red : .white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                ZStack {
                    ForEach(targets, id: \.id) { target in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .position(target.position)
                            .onTapGesture {
                                handleTap(target: target)
                            }
                            .scaleEffect(target.isHit ? 0.5 : 1.0)
                            .opacity(target.isHit ? 0.3 : 1.0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    startGame()
                }

                Spacer()
            }
        }
        .onDisappear {
            endGame()
        }
    }

    private func startGame() {
        timeRemaining = 60
        isGameActive = true
        generateTargets()

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                endGame()
            }

            if Int.random(in: 0 ... 100) < 30 && studySet.flashcards.count > 0 {
                injectFlashcard()
            }

            if targets.count < 5 {
                generateTargets()
            }
        }
    }

    private func generateTargets() {
        let newTarget = TapTarget(
            id: UUID(),
            position: CGPoint(
                x: CGFloat.random(in: 60 ... UIScreen.main.bounds.width - 60),
                y: CGFloat.random(in: 150 ... UIScreen.main.bounds.height - 200)
            ),
            isHit: false
        )
        targets.append(newTarget)
    }

    private func handleTap(target: TapTarget) {
        if let index = targets.firstIndex(where: { $0.id == target.id }) {
            withAnimation {
                targets[index].isHit = true
                score += 10
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                targets.removeAll { $0.id == target.id }
            }
        }
    }

    private func injectFlashcard() {
        if let randomFlashcard = studySet.flashcards.randomElement() {
            injectedFlashcard = randomFlashcard
            pauseGame()
        }
    }

    private func pauseGame() {
        isGameActive = false
        gameTimer?.invalidate()
    }

    private func resumeGame() {
        isGameActive = true
        startGame()
    }

    private func endGame() {
        gameTimer?.invalidate()
        isGameActive = false
        onGameEnd(score)
    }
}

struct TapTarget {
    let id: UUID
    var position: CGPoint
    var isHit: Bool
}

#Preview {
    let testSet = StudySet(title: "Test Set")
    testSet.flashcards = [
        Flashcard(setId: testSet.id, front: "What is 2+2?", back: "4", difficulty: 1),
        Flashcard(setId: testSet.id, front: "Capital of France?", back: "Paris", difficulty: 1),
    ]

    let container = try! ModelContainer(
        for: StudySet.self, Flashcard.self, UserProgress.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    TapGameView(studySet: testSet, onGameEnd: { _ in })
        .modelContainer(container)
}
