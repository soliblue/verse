import SwiftData
import SwiftUI

struct StoryImageView: View {
    @Environment(\.modelContext) private var context
    let url: URL
    let alt: String?
    let api: APIClient
    let height: CGFloat?
    @State private var store = StoryImageStore()

    var body: some View {
        Group {
            if let image = store.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: height == nil ? .fit : .fill)
            } else {
                Rectangle()
                    .fill(VerseTheme.surface)
                    .overlay { ProgressView() }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .accessibilityLabel(alt ?? "")
        .task(id: url) {
            await store.load(url: url, api: api, context: context)
        }
    }
}
