import Foundation
import SwiftData

@Model
final class StudySet {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, minimumModelCount: 0) var flashcards: [Flashcard] = []

    init(title: String) {
        self.title = title
    }

    var flashcardCount: Int {
        flashcards.count
    }
}
