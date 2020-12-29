//
//  CardGridView.swift
//  OmenAnimationExample
//
//  Created by Kit Langton on 12/29/20.
//

import SwiftUI

struct Card: Identifiable, Hashable {
    var id = UUID()
    var rank = Int.random(in: 1 ... 9)
    var isComplete = false

    mutating func rankUp() {
        rank += 1
        if rank >= 10 {
            rank = 1
        }
    }
}

struct RingBuffer<A> {
    var items = [A]()
    var currentIndex: Int = 0

    var current: A {
        get {
            items[currentIndex]
        }
        set {
            items[currentIndex] = newValue
        }
    }

    mutating func next() {
        currentIndex += 1
        normalizeIndex()
    }

    mutating func pop() -> A {
        defer { normalizeIndex() }
        return items.remove(at: currentIndex)
    }

    mutating func normalizeIndex() {
        if currentIndex >= items.count {
            currentIndex = 0
        }
    }
}

enum CardLayout {
    case study, stack, grid

    mutating func next() {
        switch self {
        case .study:
            self = .grid
        case .stack:
            self = .study
        case .grid:
            self = .stack
        }
    }
}

class Session: ObservableObject {
    @Published var buffer = RingBuffer<Card>(items: [Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card(), Card()])
    @Published var completed = [Card]()
    @Published var isLevelingUp = false
    @Published var layout = CardLayout.study

    var cards: [Card] { buffer.items }

    func reset() {
        buffer.items = buffer.items + completed
        completed = []
        buffer.currentIndex = 0
    }

    func complete() {
        isLevelingUp = false
        completed.insert(buffer.pop(), at: 0)
    }

    func levelUp() {
        buffer.current.rankUp()
        isLevelingUp = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.complete()
        }
    }

    private var stackPositions: [PositionedCard] {
        (cards + completed).enumerated().map { index, card in
            PositionedCard(
                x: 0,
                y: 0,
                shadow: index > 0 ? 0.2 : 0,
                zIndex: -Double(index),
                card: card
            )
        }
    }

    private var gridPositions: [PositionedCard] {
        (cards + completed).enumerated().map { index, card in

            PositionedCard(
                x: 0,
                y: 0,
                zIndex: -Double(index),
                card: card
            )
        }
    }

    private var studyingCardPositions: [PositionedCard] {
        cards.enumerated().map { index, card in
            PositionedCard.forStudyingCard(
                card,
                index: index,
                currentIndex: buffer.currentIndex,
                isLevelingUp: isLevelingUp
            )
        }
    }

    private func completedCardPositions(frameWidth: CGFloat) -> [PositionedCard] {
        completed.enumerated().map { index, card in
            PositionedCard.forCompletedCard(card, index: index, frameWidth: frameWidth)
        }
    }

    func cardLayouts(_ frameWidth: CGFloat) -> [PositionedCard] {
        switch layout {
        case .study:
            return studyingCardPositions + completedCardPositions(frameWidth: frameWidth)
        case .grid:
            return (cards + completed).enumerated().map { index, card in
                PositionedCard.forGrid(card, index: index, frameWidth: frameWidth)
            }
        case .stack:
            return stackPositions
        }
    }
}

struct PositionedCard: View, Identifiable, Hashable {
    var id: UUID { card.id }
    let x: CGFloat
    let y: CGFloat
    var delay: Double = 0
    var response: Double = 0.6
    var shadow: Double = 0.0
    var zIndex: Double = 0
    let card: Card

    var body: some View {
        CardView(card: card, size: K.cardSize, shadow: shadow)
            .zIndex(zIndex)
            .offset(
                x: x,
                y: y
            )
            .animation(
                Animation
                    .spring(response: response, dampingFraction: 0.8)
                    .delay(delay)
            )
            .shadow(radius: 4)
    }
}

extension PositionedCard {
    static func forStudyingCard(_ card: Card, index: Int, currentIndex: Int, isLevelingUp: Bool) -> PositionedCard {
        let isSelected = index == currentIndex

        var position = Double(index - currentIndex)

        var shadow = isSelected ? 0 : 0.3

        let distancePastMax = max(0, position - K.maxX)
        position = min(position, K.maxX)
        position += distancePastMax * 0.3
        shadow += min(1, distancePastMax * 0.2)
        shadow += position < 0 ? 0.6 : 0

        let x = CGFloat(position) * (K.cardSpacing + K.cardSize)

        var y: CGFloat = 0
        if isSelected {
            y -= 10
            if isLevelingUp {
                y -= 10
            }
        }

        return PositionedCard(
            x: x,
            y: y,
            delay: Double(abs(position)) * 0.02,
            response: isLevelingUp ? 0.4 : 0.6,
            shadow: shadow,
            zIndex: Double(index * -1),
            card: card
        )
    }

    static func forCompletedCard(_ card: Card, index: Int, frameWidth: CGFloat) -> PositionedCard {
        var card = card
        card.isComplete = true
        return PositionedCard(x: frameWidth - K.cardSize,
                              y: CGFloat(index) * (K.cardSize / 3),
                              shadow: Double(index) * 0.3,
                              zIndex: Double(-1 * index),
                              card: card)
    }

    static func forGrid(_ card: Card, index: Int, frameWidth: CGFloat) -> PositionedCard {
        let rowSize = 3
        let row = index / rowSize
        let position = index % rowSize
        let x = CGFloat(position) * K.cardGap

        return PositionedCard(x: x, y: CGFloat(row) * K.cardGap, zIndex: -Double(index), card: card)
    }

    enum K {
        static var cardSize: CGFloat { 35 }
        static var cardSpacing: CGFloat { cardSize / 4 }
        static var cardGap: CGFloat { cardSize + cardSpacing }
        static var maxX: Double { 4 }
    }
}

struct CardGridView: View {
    @StateObject var session = Session()

    var body: some View {
        VStack {
            GeometryReader { geo in
                ForEach(session.cardLayouts(geo.size.width)) { layout in
                    layout
                }
            }
            .padding()

            HStack {
                Spacer()
                Button { session.buffer.next() } label: { Text("Next") }
                Spacer()
                Button { session.levelUp() } label: { Text("Complete") }
                Spacer()
                Button { session.layout.next() } label: { Text("Grid") }
                Spacer()
                Button { session.reset() } label: { Text("Reset").foregroundColor(.red) }
                Spacer()
            }.frame(maxWidth: .infinity)
        }
        .padding(.vertical)
        .padding(.vertical)
    }
}

struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        CardGridView()
            .preferredColorScheme(.dark)
    }
}
