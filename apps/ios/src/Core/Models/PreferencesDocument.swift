import Foundation

struct PreferencesDocument: Codable, Equatable {
    var markdown: String

    init(markdown: String) {
        self.markdown = markdown
    }

    init(topics: [Topic]) {
        let sections = topics.sorted { $0.position < $1.position }.map { topic in
            let name = topic.name.replacingOccurrences(of: "\n", with: " ")
            let description = topic.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return """
            ## \(name)
            - id: \(topic.id)
            - kind: \(topic.kind.rawValue)
            - enabled: \(topic.isEnabled)
            - position: \(topic.position)

            \(description)
            """
        }
        markdown = """
        ---
        version: 1
        ---

        # Preferences

        \(sections.joined(separator: "\n\n"))

        """
    }
}
