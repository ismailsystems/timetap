import Foundation

enum TimetapAPIError: LocalizedError {
    case notConfigured
    case badURL
    case http(Int, String)
    case server(String)
    case decode

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set the API URL and token in Settings"
        case .badURL: return "API URL is not a valid URL"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .server(let msg): return msg
        case .decode: return "Could not read the server reply"
        }
    }
}

/// Posts JSON to the Apps Script `/exec` deployment.
///
/// Apps Script often 302s the first POST onto a googleusercontent host and
/// drops the body if the client turns the redirect into a GET. The session
/// below re-issues the same POST on redirect.
final class TimetapAPI: NSObject, URLSessionTaskDelegate {
    static let shared = TimetapAPI()

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 30
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    func config() async throws -> ClientConfig {
        try await post(action: "config", ops: nil)
    }

    func getState() async throws -> ServerState {
        try await post(action: "getState", ops: nil)
    }

    func applyOps(_ ops: [Op]) async throws -> ApplyResult {
        try await post(action: "applyOps", ops: ops)
    }

    private func post<T: Decodable>(action: String, ops: [Op]?) async throws -> T {
        guard Credentials.isConfigured else { throw TimetapAPIError.notConfigured }
        var urlString = Credentials.apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix("/") { urlString.removeLast() }
        guard let url = URL(string: urlString) else { throw TimetapAPIError.badURL }

        var payload: [String: Any] = [
            "token": Credentials.apiToken,
            "action": action
        ]
        if let ops {
            let data = try JSONEncoder().encode(ops)
            payload["ops"] = try JSONSerialization.jsonObject(with: data)
        }
        let body = try JSONSerialization.data(withJSONObject: payload)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw TimetapAPIError.decode }
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            throw TimetapAPIError.http(http.statusCode, text)
        }

        let env = try JSONDecoder().decode(ApiEnvelope<T>.self, from: data)
        guard env.ok, let result = env.result else {
            throw TimetapAPIError.server(env.error ?? "request failed")
        }
        return result
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var next = request
        if task.originalRequest?.httpMethod == "POST" {
            next.httpMethod = "POST"
            if next.httpBody == nil {
                next.httpBody = task.originalRequest?.httpBody
            }
            if next.value(forHTTPHeaderField: "Content-Type") == nil {
                next.setValue(
                    "application/json; charset=utf-8",
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }
        completionHandler(next)
    }
}
