import SwiftUI

struct ChatHistoryView: View {
    @Binding var sessions: [ChatSession]
    @Binding var selectedSessionID: UUID?

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let id = selectedSessionID,
                       let idx = sessions.firstIndex(where: { $0.id == id }) {
                        ForEach(sessions[idx].messages) { msg in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(msg.author)
                                    .font(.caption)
                                    .foregroundColor(.accentColor) // ✅ .accentColor — стандартный способ для выделения цветом
                                Text(msg.text)
                                    .padding(10)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity, alignment: msg.author == "Вы" ? .trailing : .leading)
                            }
                            .id(msg.id)
                            .padding(.horizontal, 8)
                        }
                    } else {
                        Text("Выберите чат или создайте новый")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: sessions) { _ in
                // автоскролл к последнему сообщению, если есть
                if let id = selectedSessionID,
                   let idx = sessions.firstIndex(where: { $0.id == id }),
                   let lastId = sessions[idx].messages.last?.id {
                    withAnimation {
                        reader.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: selectedSessionID) { _ in
                if let id = selectedSessionID,
                   let idx = sessions.firstIndex(where: { $0.id == id }),
                   let lastId = sessions[idx].messages.last?.id {
                    withAnimation {
                        reader.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}
