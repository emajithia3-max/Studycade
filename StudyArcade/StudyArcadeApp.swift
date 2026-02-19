import SwiftUI
import SwiftData

@main
struct StudyArcadeApp: App {
    let modelContainer: ModelContainer

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }

    init() {
        let schema = Schema([StudySet.self, Flashcard.self, UserProgress.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
}
