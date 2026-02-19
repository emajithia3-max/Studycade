import SwiftUI

struct GameInfo: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let description: String
}

struct GameSelectionView: View {
    let studySet: StudySet
    @Environment(\.dismiss) private var dismiss

    private let games: [GameInfo] = [
        GameInfo(name: "Tap Targets", icon: "hand.tap.fill", color: .blue, description: "Tap circles before they vanish"),
        GameInfo(name: "Slice Storm", icon: "scissors", color: .red, description: "Slice objects flying across the screen"),
        GameInfo(name: "Tower Stack", icon: "square.stack.3d.up.fill", color: .orange, description: "Time your drops to build the tallest tower"),
        GameInfo(name: "Tile Merge", icon: "square.grid.2x2.fill", color: .yellow, description: "Swipe to merge tiles and reach 2048"),
        GameInfo(name: "Mole Smash", icon: "hammer.fill", color: .brown, description: "Whack moles before they hide"),
        GameInfo(name: "Flap Dash", icon: "bird.fill", color: .cyan, description: "Tap to fly through the gaps"),
        GameInfo(name: "Block Drop", icon: "rectangle.split.3x3.fill", color: .purple, description: "Place shapes to clear rows"),
        GameInfo(name: "Snake Munch", icon: "circle.circle.fill", color: .green, description: "Grow your snake, don't hit the walls"),
        GameInfo(name: "Brick Breaker", icon: "rectangle.3.group.fill", color: .pink, description: "Bounce the ball to smash bricks"),
        GameInfo(name: "Gem Match", icon: "diamond.fill", color: .indigo, description: "Swap gems to match three or more"),
        GameInfo(name: "Star Catcher", icon: "star.fill", color: .yellow, description: "Move your basket to catch falling stars"),
        GameInfo(name: "Space Blaster", icon: "sparkle", color: .gray, description: "Blast incoming alien ships"),
        GameInfo(name: "Bubble Shooter", icon: "bubble.left.and.bubble.right.fill", color: .teal, description: "Aim and pop bubble clusters"),
        GameInfo(name: "Pattern Pulse", icon: "waveform.path", color: .purple, description: "Repeat the color pattern"),
        GameInfo(name: "Color Dash", icon: "paintpalette.fill", color: .orange, description: "Pass through matching color gates"),
        GameInfo(name: "Rhythm Tap", icon: "music.note", color: .pink, description: "Tap falling notes on beat"),
        GameInfo(name: "Pong Rally", icon: "tennis.racket", color: .green, description: "Classic paddle battle"),
        GameInfo(name: "Maze Runner", icon: "square.grid.3x3.topleft.filled", color: .mint, description: "Find your way through the maze"),
        GameInfo(name: "Gravity Dash", icon: "figure.run", color: .red, description: "Jump and dodge obstacles"),
        GameInfo(name: "Wood Fit", icon: "puzzle.piece.fill", color: .brown, description: "Fit wooden pieces on the board"),
        GameInfo(name: "Hex Puzzle", icon: "hexagon.fill", color: .indigo, description: "Place hex pieces to clear lines"),
        GameInfo(name: "Lane Runner", icon: "road.lanes", color: .blue, description: "Dodge traffic in an endless run"),
        GameInfo(name: "Sky Jump", icon: "arrow.up.circle.fill", color: .cyan, description: "Bounce higher and higher"),
        GameInfo(name: "Card Climber", icon: "suit.spade.fill", color: .red, description: "Play higher or lower to climb"),
        GameInfo(name: "Spin & Win", icon: "circle.dotted", color: .yellow, description: "Spin the wheel for bonus points"),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    NavigationLink {
                        destinationView(for: index)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: game.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            Text(game.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(game.description)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 130)
                        .padding(.horizontal, 8)
                        .background(game.color.gradient)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Choose a Game")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destinationView(for index: Int) -> some View {
        let handler: (Int) -> Void = { _ in }
        switch index {
        case 0: TapGameView(studySet: studySet, onGameEnd: handler)
        case 1: SliceStormGameView(studySet: studySet, onGameEnd: handler)
        case 2: TowerStackGameView(studySet: studySet, onGameEnd: handler)
        case 3: TileMergeGameView(studySet: studySet, onGameEnd: handler)
        case 4: MoleSmashGameView(studySet: studySet, onGameEnd: handler)
        case 5: FlapDashGameView(studySet: studySet, onGameEnd: handler)
        case 6: BlockDropGameView(studySet: studySet, onGameEnd: handler)
        case 7: SnakeGameView(studySet: studySet, onGameEnd: handler)
        case 8: BrickBreakerGameView(studySet: studySet, onGameEnd: handler)
        case 9: GemMatchGameView(studySet: studySet, onGameEnd: handler)
        case 10: StarCatcherGameView(studySet: studySet, onGameEnd: handler)
        case 11: SpaceBlasterGameView(studySet: studySet, onGameEnd: handler)
        case 12: BubbleShooterGameView(studySet: studySet, onGameEnd: handler)
        case 13: PatternPulseGameView(studySet: studySet, onGameEnd: handler)
        case 14: ColorDashGameView(studySet: studySet, onGameEnd: handler)
        case 15: RhythmTapGameView(studySet: studySet, onGameEnd: handler)
        case 16: PongRallyGameView(studySet: studySet, onGameEnd: handler)
        case 17: MazeRunnerGameView(studySet: studySet, onGameEnd: handler)
        case 18: GravityDashGameView(studySet: studySet, onGameEnd: handler)
        case 19: WoodFitGameView(studySet: studySet, onGameEnd: handler)
        case 20: HexPuzzleGameView(studySet: studySet, onGameEnd: handler)
        case 21: LaneRunnerGameView(studySet: studySet, onGameEnd: handler)
        case 22: SkyJumpGameView(studySet: studySet, onGameEnd: handler)
        case 23: CardClimberGameView(studySet: studySet, onGameEnd: handler)
        case 24: SpinWinGameView(studySet: studySet, onGameEnd: handler)
        default: TapGameView(studySet: studySet, onGameEnd: handler)
        }
    }
}
