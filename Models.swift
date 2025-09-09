import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var author: String
    var text: String
}

struct ChatSession: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var title: String
    var messages: [ChatMessage] = []
}
