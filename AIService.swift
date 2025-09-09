import Foundation

class AIService {
    static let shared = AIService()

    
    private let openAIKey = Secrets.openAIKey
    private let geminiKey = Secrets.geminiKey


        private init() {}

        private func sendPOSTRequest(url: String, body: [String: Any], headers: [String: String], completion: @escaping (Result<String, Error>) -> Void) {
            guard let requestURL = URL(string: url) else {
                completion(.failure(NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
                return
            }

            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            let task = URLSession.shared.dataTask(with: request) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "AIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }

                // Попытка парсинга JSON -> common shapes
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // OpenAI chat completions
                    if let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any] {
                        // message["content"] может быть строкой или объектом
                        if let contentStr = message["content"] as? String {
                            completion(.success(contentStr))
                            return
                        } else if let contentObj = message["content"] as? [String: Any],
                                  let parts = contentObj["parts"] as? [String],
                                  let first = parts.first {
                            completion(.success(first))
                            return
                        }
                    }

                    // Gemini style
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let content = first["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let text = parts.first?["text"] as? String {
                        completion(.success(text))
                        return
                    }

                    // Generic "text" field
                    if let text = json["text"] as? String {
                        completion(.success(text))
                        return
                    }

                    // Fallback: raw JSON string
                    if let raw = String(data: data, encoding: .utf8) {
                        completion(.success(raw))
                        return
                    }
                } else if let raw = String(data: data, encoding: .utf8) {
                    completion(.success(raw))
                    return
                }

                completion(.failure(NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Parsing error"])))
            }
            task.resume()
        }

        // ChatGPT (OpenAI)
        func fetchChatGPT(prompt: String, completion: @escaping (String) -> Void) {
            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0.7
            ]
            let headers = [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(openAIKey)"
            ]
            sendPOSTRequest(url: "https://api.openai.com/v1/chat/completions", body: body, headers: headers) { result in
                switch result {
                case .success(let s): completion(s)
                case .failure(let e): completion("Ошибка ChatGPT: \(e.localizedDescription)")
                }
            }
        }

        // Gemini (Google Generative API)
        func fetchGemini(prompt: String, completion: @escaping (String) -> Void) {
            // Используем ключ через header x-goog-api-key (иногда требуется query param ?key=..., в зависимости от аккаунта)
            let body: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]]
            ]
            let headers = [
                "Content-Type": "application/json",
                "x-goog-api-key": geminiKey
            ]
            sendPOSTRequest(url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent", body: body, headers: headers) { result in
                switch result {
                case .success(let s): completion(s)
                case .failure(let e): completion("Ошибка Gemini: \(e.localizedDescription)")
                }
            }
        }
    }
