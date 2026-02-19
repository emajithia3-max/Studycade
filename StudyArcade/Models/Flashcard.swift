import Foundation
import SwiftData

@Model
final class Flashcard {
    var id: UUID = UUID()
    var setId: UUID
    var front: String
    var back: String
    var difficulty: Int
    var timesSeen: Int = 0
    var timesCorrect: Int = 0

    init(setId: UUID, front: String, back: String, difficulty: Int = 1) {
        self.setId = setId
        self.front = front
        self.back = back
        self.difficulty = difficulty
    }

    var accuracy: Double {
        guard timesSeen > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesSeen)
    }

    func markSeen(correct: Bool) {
        timesSeen += 1
        if correct {
            timesCorrect += 1
        }
    }
}
