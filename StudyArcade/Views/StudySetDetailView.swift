import SwiftUI
import SwiftData

struct StudySetDetailView: View {
    let studySet: StudySet
    @Environment(\.modelContext) var modelContext
    @State private var showingNewFlashcardSheet = false
    @State private var showingGameSelection = false
    @State private var selectedGame: GameType?

    var body: some View {
        VStack(spacing: 0) {
            if studySet.flashcards.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No Flashcards")
                        .font(.headline)
                    Text("Create flashcards to start playing games")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button(action: { showingNewFlashcardSheet = true }) {
                        Text("Add Flashcard")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxHeight: .infinity)
                .multilineTextAlignment(.center)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(studySet.flashcards) { flashcard in
                            FlashcardRowView(flashcard: flashcard)
                        }
                    }
                    .padding(16)
                }
            }

            VStack(spacing: 12) {
                Button(action: { showingNewFlashcardSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Flashcard")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Button(action: { showingGameSelection = true }) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        Text("Play Tap Game")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(studySet.flashcards.isEmpty)
            }
            .padding(16)
        }
        .navigationTitle(studySet.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewFlashcardSheet) {
            NewFlashcardView(studySet: studySet, isPresented: $showingNewFlashcardSheet)
        }
        .navigationDestination(isPresented: $showingGameSelection) {
            TapGameView(studySet: studySet) { finalScore in
                showingGameSelection = false
            }
        }
    }
}

struct FlashcardRowView: View {
    let flashcard: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Q: \(flashcard.front)")
                        .font(.headline)
                    Text("A: \(flashcard.back)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                        Text("\(flashcard.timesSeen)")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)

                    if flashcard.accuracy > 0 {
                        Text(String(format: "%.0f%%", flashcard.accuracy * 100))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            DifficultyBadge(difficulty: flashcard.difficulty)
        }
        .padding(12)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

struct DifficultyBadge: View {
    let difficulty: Int

    var color: Color {
        switch difficulty {
        case 1:
            return Color.green
        case 2:
            return Color.yellow
        default:
            return Color.red
        }
    }

    var label: String {
        switch difficulty {
        case 1:
            return "Easy"
        case 2:
            return "Medium"
        default:
            return "Hard"
        }
    }

    var body: some View {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct NewFlashcardView: View {
    let studySet: StudySet
    @Binding var isPresented: Bool
    @Environment(\.modelContext) var modelContext
    @State private var front = ""
    @State private var back = ""
    @State private var difficulty = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextEditor(text: $front)
                        .frame(height: 80)
                }
                Section("Answer") {
                    TextEditor(text: $back)
                        .frame(height: 80)
                }
                Section("Difficulty") {
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Easy").tag(1)
                        Text("Medium").tag(2)
                        Text("Hard").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newFlashcard = Flashcard(
                            setId: studySet.id,
                            front: front,
                            back: back,
                            difficulty: difficulty
                        )
                        studySet.flashcards.append(newFlashcard)
                        modelContext.insert(newFlashcard)
                        isPresented = false
                    }
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty ||
                        back.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

enum GameType {
    case tap
}

#Preview {
    let container = try! ModelContainer(
        for: StudySet.self, Flashcard.self, UserProgress.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let testSet = StudySet(title: "Test Set")
    testSet.flashcards = [
        Flashcard(setId: testSet.id, front: "What is 2+2?", back: "4", difficulty: 1),
        Flashcard(setId: testSet.id, front: "Capital of France?", back: "Paris", difficulty: 1),
    ]

    return NavigationStack {
        StudySetDetailView(studySet: testSet)
            .modelContainer(container)
    }
}
