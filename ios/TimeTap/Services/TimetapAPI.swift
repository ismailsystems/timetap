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
/// ContentService replies with 302 → `script.googleusercontent.com/macros/echo`.
/// The JSON is already produced; the echo URL must be fetched with GET.
/// Re-POSTing that URL returns HTTP 405.
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

    func addCategory(label: String) async throws -> ClientConfig {
        try await post(action: "addCategory", ops: nil, label: label)
    }

    private func post<T: Decodable>(
        action: String,
        ops: [Op]?,
        label: String? = nil
    ) async throws -> T {
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
        if let label {
            payload["label"] = label
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
        // Force GET on the echo hop even if URLSession kept POST (some iOS builds do).
        if let host = request.url?.host,
           host.contains("googleusercontent.com"),
           request.url?.path.contains("/macros/echo") == true {
            next.httpMethod = "GET"
            next.httpBody = nil
            next.setValue(nil, forHTTPHeaderField: "Content-Type")
            next.setValue(nil, forHTTPHeaderField: "Content-Length")
        }
        completionHandler(next)
    }
}
