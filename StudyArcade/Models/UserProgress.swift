import Foundation
import SwiftData

@Model
final class UserProgress {
    var xp: Int = 0
    var level: Int = 1
    var streak: Int = 0
    var lastPlayedAt: Date?

    var xpForNextLevel: Int {
        level * 100
    }

    var xpInCurrentLevel: Int {
        xp % xpForNextLevel
    }

    func addXP(_ amount: Int) -> Bool {
        let previousLevel = level
        xp += amount
        updateLevel()
        lastPlayedAt = Date()
        return level > previousLevel
    }

    private func updateLevel() {
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
        }
    }

    func incrementStreak() {
        streak += 1
    }

    func resetStreak() {
        streak = 0
    }
}
