import SwiftUI
import UIKit

struct StoryCoverImage: View {
    let url: URL
    let title: String
    let covers: CoverRepository?
    @State private var data: Data?

    var body: some View {
        ZStack {
            VerseTheme.paper
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VerseGlyph(size: 32)
                    .foregroundStyle(VerseTheme.secondaryInk)
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
}
