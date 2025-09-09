import Foundation

@MainActor
class AIViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = [] {
        didSet { saveSessions() }
    }
    @Published var selectedSessionID: UUID? = nil
    @Published var currentPrompt: String = ""
    @Published var isLoading: Bool = false

    private let storageKey = "AICompare.chatSessions"

    init() {
        loadSessions()
        if sessions.isEmpty {
            // создаём дефолтную сессию
            createNewChat(title: "Чат 1")
        }
    }

    // MARK: - session helpers
    func createNewChat(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? "Чат \(sessions.count + 1)" : trimmed
        let s = ChatSession(title: finalTitle)
        sessions.append(s)
        selectedSessionID = s.id
    }

    func selectSession(by id: UUID) {
        selectedSessionID = id
    }

    func selectSession(_ session: ChatSession) {
        selectedSessionID = session.id
    }

    private func indexOfSelected() -> Int? {
        guard let id = selectedSessionID else { return nil }
        return sessions.firstIndex { $0.id == id }
    }

    // MARK: - send prompt + dynamic typing
    func sendPrompt(_ prompt: String) {
        guard let idx = indexOfSelected() else { return }
        // добавляем пользовательское сообщение
        let userMsg = ChatMessage(author: "Вы", text: prompt)
        sessions[idx].messages.append(userMsg)
        currentPrompt = ""
        isLoading = true

        // Асинхронно: ChatGPT, затем Gemini (параллельно или последовательнно — здесь запускаем параллельно, оба печатаются в одну сессию).
        Task {
            // ChatGPT
            await fetchAndType(modelName: "ChatGPT", prompt: prompt, sessionIndex: idx)
        }
        Task {
            // Gemini
            await fetchAndType(modelName: "Gemini", prompt: prompt, sessionIndex: idx)
        }

        // Убираем isLoading, когда оба завершатся — самый простой способ: проверяем в background через короткую задержку
        Task {
            // ждём немного, лучше вызвать через DispatchGroup, но упрощаем:
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s, безопасный fallback
            isLoading = false
        }
    }

    private func fetchAndType(modelName: String, prompt: String, sessionIndex: Int) async {
        // получаем текст от сервиса (блокирующий через completion)
        let textResult: String = await withCheckedContinuation { cont in
            if modelName == "ChatGPT" {
                AIService.shared.fetchChatGPT(prompt: prompt) { s in cont.resume(returning: s) }
            } else {
                AIService.shared.fetchGemini(prompt: prompt) { s in cont.resume(returning: s) }
            }
        }

        // type-in effect: добавляем пустое сообщение и по-символьно обновляем
        await MainActor.run {
            sessions[sessionIndex].messages.append(ChatMessage(author: modelName, text: ""))
            // сохраняем immediately
            saveSessions()
        }

        var current = ""
        let chars = Array(textResult)
        for i in 0..<chars.count {
            current.append(chars[i])
            await MainActor.run {
                // обновляем последний сообщение в сессии
                if sessions.indices.contains(sessionIndex),
                   let msgIndex = sessions[sessionIndex].messages.lastIndex(where: { $0.author == modelName && $0.text.count <= current.count }) {
                    // Здесь мы предполагаем, что последний такой message — та, что печатается
                    sessions[sessionIndex].messages[msgIndex].text = current
                } else if sessions.indices.contains(sessionIndex) {
                    // fallback: присвоить последнему элементу
                    sessions[sessionIndex].messages[sessions[sessionIndex].messages.count - 1].text = current
                }
            }
            try? await Task.sleep(nanoseconds: 18_000_000) // 18 ms
        }

        // окончательно присваиваем полный текст и сохраняем
        await MainActor.run {
            if sessions.indices.contains(sessionIndex),
               let last = sessions[sessionIndex].messages.lastIndex(where: { $0.author == modelName }) {
                sessions[sessionIndex].messages[last].text = textResult
            }
            saveSessions()
        }
    }

    // MARK: - persistence
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Save error:", error)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([ChatSession].self, from: data)
            sessions = decoded
            selectedSessionID = sessions.first?.id
        } catch {
            print("Load error:", error)
        }
    }
}
