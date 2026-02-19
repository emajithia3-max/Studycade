import SwiftUI

struct SpinWinGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var score = 0
    @State private var spinsLeft = 10
    @State private var gameOver = false
    @State private var lastWin = 0
    @State private var showWin = false
    @State private var flashcardActive = false
    @State private var currentFlashcard: Flashcard?
    @State private var showAnswer = false
    @State private var multiplier = 1

    let studySet: StudySet
    let onGameEnd: (Int) -> Void

    private let segments: [(String, Color, Int)] = [
        ("10", .blue, 10),
        ("25", .green, 25),
        ("50", .orange, 50),
        ("💀", .red, 0),
        ("100", .purple, 100),
        ("5", .cyan, 5),
        ("75", .yellow, 75),
        ("x2", .pink, -1), // multiplier
    ]

    init(studySet: StudySet, onGameEnd: @escaping (Int) -> Void) {
        self.studySet = studySet
        self.onGameEnd = onGameEnd
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.3), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Spins: \(spinsLeft)")
                        .font(.title3).foregroundColor(.white)
                    Spacer()
                    if multiplier > 1 {
                        Text("x\(multiplier) Active!")
                            .font(.headline).foregroundColor(.yellow)
                    }
                    Spacer()
                    Text("💰 \(score)")
                        .font(.title2).bold().foregroundColor(.yellow)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Wheel
                ZStack {
                    // Segments
                    ForEach(0..<segments.count, id: \.self) { i in
                        let startAngle = Double(i) / Double(segments.count) * 360
                        let endAngle = Double(i + 1) / Double(segments.count) * 360

                        WheelSegment(startAngle: startAngle, endAngle: endAngle)
                            .fill(segments[i].1.opacity(0.8))
                            .frame(width: 280, height: 280)

                        let midAngle = (startAngle + endAngle) / 2 - 90
                        let rad = midAngle * .pi / 180
                        Text(segments[i].0)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .position(
                                x: 140 + cos(rad) * 90,
                                y: 140 + sin(rad) * 90
                            )
                            .frame(width: 280, height: 280)
                    }

                    // Center pin
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(radius: 4)
                }
                .rotationEffect(.degrees(rotation))
                .frame(width: 280, height: 280)

                // Pointer
                Triangle2()
                    .fill(Color.white)
                    .frame(width: 24, height: 20)
                    .offset(y: -150)
                    .shadow(radius: 2)

                if showWin {
                    Text(lastWin > 0 ? "+\(lastWin) points!" : (lastWin == 0 ? "💀 Lost half!" : "x2 Multiplier!"))
                        .font(.title2).bold()
                        .foregroundColor(lastWin > 0 ? .green : (lastWin == 0 ? .red : .yellow))
                        .transition(.scale)
                }

                // Spin button
                Button {
                    spin()
                } label: {
                    Text("🎰 SPIN!")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(width: 200, height: 56)
                        .background(isSpinning || spinsLeft <= 0 ? Color.gray : Color.orange)
                        .cornerRadius(28)
                        .shadow(color: .orange.opacity(0.5), radius: isSpinning ? 0 : 8)
                }
                .disabled(isSpinning || spinsLeft <= 0 || gameOver)

                Spacer()
            }
            .padding(.top, 16)

            if flashcardActive, let card = currentFlashcard {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("🎰 Bonus Spin! 🎰").font(.headline).foregroundColor(.yellow)
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
                            Button("Got it! +2 Spins") {
                                card.markSeen(correct: true)
                                spinsLeft += 2
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
                    Text("No More Spins!").font(.largeTitle).bold().foregroundColor(.white)
                    Text("Total: \(score)").font(.title).foregroundColor(.yellow)
                    Button("Done") { endGame() }
                        .font(.headline)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(14)
                }
            }
        }
        .navigationTitle("Spin & Win")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func spin() {
        guard !isSpinning && spinsLeft > 0 else { return }
        isSpinning = true
        spinsLeft -= 1
        showWin = false

        let extraRotations = Double.random(in: 3...6) * 360
        let targetRotation = rotation + extraRotations

        withAnimation(.easeOut(duration: 3.0)) {
            rotation = targetRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            let normalizedAngle = targetRotation.truncatingRemainder(dividingBy: 360)
            let segmentAngle = 360.0 / Double(segments.count)
            let adjustedAngle = (360 - normalizedAngle).truncatingRemainder(dividingBy: 360)
            let segmentIndex = Int(adjustedAngle / segmentAngle) % segments.count

            let segment = segments[segmentIndex]

            if segment.2 == 0 {
                // Skull - lose half
                score = score / 2
                lastWin = 0
            } else if segment.2 == -1 {
                // Multiplier
                multiplier = min(multiplier * 2, 8)
                lastWin = -1
            } else {
                let points = segment.2 * multiplier
                score += points
                lastWin = points
            }

            withAnimation { showWin = true }
            isSpinning = false

            if spinsLeft <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { gameOver = true }
            } else if spinsLeft % 3 == 0 && !studySet.flashcards.isEmpty {
                currentFlashcard = studySet.flashcards.randomElement()
                self.showAnswer = false
                flashcardActive = true
            }
        }
    }

    private func endGame() {
        onGameEnd(score)
        dismiss()
    }
}

private struct WheelSegment: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(startAngle - 90),
                    endAngle: .degrees(endAngle - 90),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct Triangle2: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
