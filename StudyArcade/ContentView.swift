import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var studySets: [StudySet]
    @Query var userProgress: [UserProgress]
    @EnvironmentObject var storeManager: StoreManager

    @State private var showingNewSetSheet = false
    @State private var showingSelectedGame: UUID?
    @State private var selectedStudySet: StudySet?

    var currentProgress: UserProgress {
        if let existing = userProgress.first {
            return existing
        }
        let newProgress = UserProgress()
        modelContext.insert(newProgress)
        return newProgress
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level \(currentProgress.level)")
                                .font(.title2)
                                .fontWeight(.bold)
                            ProgressView(
                                value: Double(currentProgress.xpInCurrentLevel),
                                total: Double(currentProgress.xpForNextLevel)
                            )
                            .frame(height: 8)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(currentProgress.xp) XP")
                                .font(.headline)
                            Text("Streak: \(currentProgress.streak)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(16)

                if studySets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Study Sets")
                            .font(.headline)
                        Text("Create a study set to get started")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: { showingNewSetSheet = true }) {
                            Text("Create Your First Set")
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .multilineTextAlignment(.center)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(studySets) { studySet in
                                NavigationLink(destination: StudySetDetailView(studySet: studySet)) {
                                    StudySetCard(studySet: studySet)
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: { showingNewSetSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("New Study Set")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    NavigationLink(destination: SubscriptionView()) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Upgrade to Pro")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.yellow)
                        .cornerRadius(8)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Study Arcade")
            .sheet(isPresented: $showingNewSetSheet) {
                NewStudySetView(isPresented: $showingNewSetSheet)
            }
        }
    }
}

struct StudySetCard: View {
    let studySet: StudySet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(studySet.title)
                .font(.headline)
            HStack {
                Label("\(studySet.flashcardCount) cards", systemImage: "rectangle.on.rectangle")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NewStudySetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) var modelContext
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Study Set Name") {
                    TextField("Enter name", text: $title)
                }
            }
            .navigationTitle("New Study Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newSet = StudySet(title: title)
                        modelContext.insert(newSet)
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: StudySet.self, Flashcard.self, UserProgress.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let previewSet = StudySet(title: "Preview Set")
    previewSet.flashcards = [
        Flashcard(setId: previewSet.id, front: "What is 2+2?", back: "4"),
    ]

    let progress = UserProgress()
    progress.xp = 250
    progress.level = 5

    return ContentView()
        .modelContainer(container)
        .environmentObject(StoreManager())
        .onAppear {
            container.mainContext.insert(previewSet)
            container.mainContext.insert(progress)
        }
}
