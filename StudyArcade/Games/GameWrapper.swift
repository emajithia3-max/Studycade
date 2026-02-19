import SwiftUI
import SwiftData

struct GameWrapper<Content: View>: View {
    @State private var isPaused = false
    @State private var currentFlashcard: Flashcard?
    @State private var showFlashcard = false
    @State private var userAnswer = ""
    @State private var showAnswer = false
    @State private var xpGained = 0
    @State private var showXPPopup = false

    @Environment(\.modelContext) var modelContext

    let content: Content
    let onFlashcardAnswered: (Flashcard, Bool) -> Void
    let onXPGained: (Int) -> Void

    init(
        @ViewBuilder content: @escaping () -> Content,
        onFlashcardAnswered: @escaping (Flashcard, Bool) -> Void,
        onXPGained: @escaping (Int) -> Void
    ) {
        self.content = content()
        self.onFlashcardAnswered = onFlashcardAnswered
        self.onXPGained = onXPGained
    }

    var body: some View {
        ZStack {
            content
                .opacity(isPaused ? 0.3 : 1.0)

            if isPaused {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
            }

            if showFlashcard, let flashcard = currentFlashcard {
                FlashcardOverlay(
                    flashcard: flashcard,
                    userAnswer: $userAnswer,
                    showAnswer: $showAnswer,
                    onSubmit: { isCorrect in
                        handleFlashcardAnswer(flashcard, isCorrect: isCorrect)
                    },
                    onDismiss: resumeGame
                )
            }

            if showXPPopup {
                VStack {
                    Text("+\(xpGained) XP")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("Great job!")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    func injectFlashcard(_ flashcard: Flashcard) {
        pauseGame()
        currentFlashcard = flashcard
        showFlashcard = true
        userAnswer = ""
        showAnswer = false
    }

    private func pauseGame() {
        isPaused = true
    }

    func resumeGame() {
        isPaused = false
        showFlashcard = false
        currentFlashcard = nil
    }

    private func handleFlashcardAnswer(_ flashcard: Flashcard, isCorrect: Bool) {
        flashcard.markSeen(correct: isCorrect)

        let xpReward = isCorrect ? 10 + (flashcard.difficulty * 5) : 5
        xpGained = xpReward
        showXPPopup = true

        onXPGained(xpReward)
        onFlashcardAnswered(flashcard, isCorrect)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showXPPopup = false
            resumeGame()
        }
    }
}

struct FlashcardOverlay: View {
    let flashcard: Flashcard
    @Binding var userAnswer: String
    @Binding var showAnswer: Bool
    let onSubmit: (Bool) -> Void
    let onDismiss: () -> Void

    @State private var selectedAnswer: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Question")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(flashcard.front)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)

                if showAnswer {
                    VStack(spacing: 16) {
                        Text("Answer")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(flashcard.back)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
                    .transition(.opacity)

                    HStack(spacing: 16) {
                        Button(action: {
                            onSubmit(false)
                        }) {
                            Text("Incorrect")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            onSubmit(true)
                        }) {
                            Text("Correct")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Button(action: {
                        withAnimation {
                            showAnswer = true
                        }
                    }) {
                        Text("Show Answer")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
