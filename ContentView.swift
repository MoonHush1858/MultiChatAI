import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AIViewModel()
    @State private var inputText: String = ""
    @State private var showNewChatSheet = false
    @State private var newChatTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header: menu
            HStack {
                Menu {
                    // Список сессий
                    ForEach(vm.sessions) { s in
                        Button {
                            vm.selectSession(s)
                        } label: {
                            Text(s.title)
                        }
                    }
                    Divider()
                    Button("➕ Новый чат") { showNewChatSheet = true }
                } label: {
                    Label(vm.sessions.first(where: { $0.id == vm.selectedSessionID })?.title ?? "Выберите чат", systemImage: "chevron.down")
                        .padding(10)
                }

                Spacer()
                Text("создано MoonHush1858")
                    .font(.caption2)
                    .foregroundColor(.secondary) // ✅ .secondary адаптируется под тему
            }
            .padding(.horizontal)

            Divider()

            // Chat history
            ChatHistoryView(sessions: $vm.sessions, selectedSessionID: $vm.selectedSessionID)
                .background(Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input
            HStack {
                TextField("Введите сообщение...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(vm.selectedSessionID == nil)

                Button(action: {
                    guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    vm.sendPrompt(inputText)
                    inputText = ""
                }) {
                    Text("✉️")
                }
                .disabled(vm.selectedSessionID == nil || vm.isLoading)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .sheet(isPresented: $showNewChatSheet) {
            VStack(spacing: 12) {
                Text("Новый чат").font(.headline)
                TextField("Название чата", text: $newChatTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                HStack {
                    Button("Отмена") { showNewChatSheet = false; newChatTitle = "" }
                    Spacer()
                    Button("Создать") {
                        vm.createNewChat(title: newChatTitle)
                        newChatTitle = ""
                        showNewChatSheet = false
                    }
                    .disabled(newChatTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
