import SwiftUI
import UIKit

struct StoryCoverImage: View {
    let url: URL
    let title: String
    let covers: CoverRepository?
    var contentMode: ContentMode = .fit
    @State private var data: Data?

    var body: some View {
        ZStack {
            background
            if let data, let image = UIImage(data: data) {
                cover(image)
            } else {
                VerseGlyph(size: 32)
                    .foregroundStyle(placeholderInk)
            }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cover for \(title)")
        .task(id: url) {
            data = nil
            data = await covers?.data(for: url)
        }
    }

    @ViewBuilder
    private func cover(_ image: UIImage) -> some View {
        switch contentMode {
        case .fit:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        case .fill:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }

    private var background: Color {
        switch contentMode {
        case .fit: VerseTheme.paper
        case .fill: VerseTheme.mediaScrim
        }
    }

    private var placeholderInk: Color {
        switch contentMode {
        case .fit: VerseTheme.secondaryInk
        case .fill: VerseTheme.mediaInk
        }
    }
}
