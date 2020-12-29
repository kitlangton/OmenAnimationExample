//
//  CardView.swift
//  OmenAnimationExample
//
//  Created by Kit Langton on 12/29/20.
//

import SwiftUI

extension AnimatableModifier {
    var view: some View {
        Color.clear.modifier(self)
    }
}

protocol AnimatableView: View, AnimatableModifier where Body == AnyView {
    associatedtype AnimBody: View

    var animBody: AnimBody { get }
}

extension AnimatableView {
    func body(content: Content) -> AnyView {
        AnyView(animBody)
    }

    var body: AnyView {
        AnyView(view)
    }
}

struct RankView: AnimatableView {
    internal init(rank: Int) {
        self.rank = rank
        self.rank0 = Double(rank)
    }

    var rank: Int
    var rank0: Double

    var animatableData: Double {
        get { rank0 }
        set { rank0 = newValue }
    }

    var rankInt: Int { min(Int(rank), Int(rank0.rounded(.up))) }

    var animBody: some View {
        VStack {
            Text("\(rankInt)")
                .colorInvert()
                .id(rankInt)
                .transition(AnyTransition
                    .asymmetric(insertion:
                        AnyTransition.move(edge: .top).combined(with: .opacity).animation(.spring(response: 0.2)),
                        removal:
                        AnyTransition.move(edge: .bottom).combined(with: .opacity)))
        }
    }
}


struct CardView: View {
    let card: Card
    var size: CGFloat = 35
    var shadow: Double = 0.0

    var body: some View {
        RankView(rank: card.rank).view
            .font(Font.system(size: CGFloat(size / 1.5), design: .rounded).bold())
            .frame(width: size, height: size)
            .background(
                Color.primary.overlay(card.isComplete ? Color.green.opacity(0.5) : Color.clear)
                    .overlay(Color.black.opacity(shadow))
                    .compositingGroup()
            )
            .cornerRadius(size / 8.75)
            .statusBar(hidden: true)
    }
}

struct CardView_Previews: PreviewProvider {
    struct Example: View {
        @State var card = Card()
        var body: some View {
            VStack(spacing: 12) {
                ForEach(0 ..< 10) { i in
                    CardView(card: card, size: CGFloat(i * 5) + 20)
                        .onTapGesture {
                            card.rank += 5
                        }
                }
            }
        }
    }

    static var previews: some View {
        Example()
            .animation(.spring())
            .preferredColorScheme(.dark)
    }
}
