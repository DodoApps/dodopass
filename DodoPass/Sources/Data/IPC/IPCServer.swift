import Foundation

/// IPC Server for browser extension communication via Unix socket.
final class IPCServer: ObservableObject {
    // MARK: - Singleton

    static let shared = IPCServer()

    // MARK: - Properties

    private var serverSocket: Int32 = -1
    private let socketPath = "/tmp/dodopass.sock"
    private let acceptQueue = DispatchQueue(label: "com.dodopass.ipc.accept", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "com.dodopass.ipc.client", qos: .userInitiated, attributes: .concurrent)

    @Published private(set) var isRunning = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Starts the IPC server.
    func start() {
        guard !isRunning else { return }

        // Remove existing socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        // Create Unix socket using POSIX
        let sockfd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockfd >= 0 else {
            AuditLogger.shared.log("Failed to create socket", category: .app, level: .error)
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path.0) { dest in
                _ = strcpy(dest, ptr)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sockfd, sockaddrPtr, addrLen)
            }
        }

        guard bindResult == 0 else {
            AuditLogger.shared.log("Failed to bind socket: \(errno)", category: .app, level: .error)
            close(sockfd)
            return
        }

        guard listen(sockfd, 5) == 0 else {
            AuditLogger.shared.log("Failed to listen on socket: \(errno)", category: .app, level: .error)
            close(sockfd)
            return
        }

        // Set socket permissions so other processes can connect
        chmod(socketPath, 0o666)

        serverSocket = sockfd
        isRunning = true
        AuditLogger.shared.log("IPC server started at \(socketPath)", category: .app)

        // Accept connections in background
        acceptQueue.async { [weak self] in
            self?.acceptLoop(sockfd: sockfd)
        }
    }

    private func acceptLoop(sockfd: Int32) {
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(sockfd, sockaddrPtr, &clientAddrLen)
                }
            }

            if clientFd >= 0 {
                clientQueue.async { [weak self] in
                    self?.handleClient(fd: clientFd)
                }
            }
        }
        close(sockfd)
    }

    private func handleClient(fd: Int32) {
        // Read data
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)

        guard bytesRead > 0 else {
            close(fd)
            return
        }

        let data = Data(bytes: buffer, count: bytesRead)

        guard let message = try? JSONDecoder().decode(IPCMessage.self, from: data) else {
            let errorResponse = IPCResponse(success: false, command: "error", error: "Invalid message format")
            sendResponse(errorResponse, toFd: fd)
            return
        }

        // Process message and respond asynchronously
        Task { @MainActor [weak self] in
            let response = await self?.processMessage(message) ?? IPCResponse(success: false, command: message.command, error: "Server error")
            self?.sendResponse(response, toFd: fd)
        }
    }

    private func sendResponse(_ response: IPCResponse, toFd fd: Int32) {
        if let responseData = try? JSONEncoder().encode(response) {
            _ = responseData.withUnsafeBytes { ptr in
                write(fd, ptr.baseAddress!, responseData.count)
            }
        }
        close(fd)
    }

    /// Stops the IPC server.
    func stop() {
        isRunning = false

        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }

        try? FileManager.default.removeItem(atPath: socketPath)
        AuditLogger.shared.log("IPC server stopped", category: .app)
    }

    // MARK: - Message Processing

    @MainActor
    private func processMessage(_ message: IPCMessage) async -> IPCResponse {
        let vaultManager = VaultManager.shared

        switch message.command {
        case "status":
            let itemCount = vaultManager.isLocked ? 0 : vaultManager.items.allItems.count
            return IPCResponse(
                success: true,
                command: message.command,
                data: [
                    "locked": vaultManager.isLocked,
                    "vaultExists": vaultManager.vaultExists,
                    "itemCount": itemCount
                ]
            )

        case "search":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let query: String = message.param("query") else {
                return IPCResponse(success: false, command: message.command, error: "Missing query parameter")
            }

            let results = vaultManager.search(query: query)
            let items = results.prefix(10).map { item -> [String: Any] in
                var dict: [String: Any] = [
                    "id": item.id.uuidString,
                    "title": item.title,
                    "category": item.category.rawValue
                ]

                if let login = item as? LoginItem {
                    dict["username"] = login.username
                    dict["url"] = login.urls.first ?? ""
                }

                return dict
            }

            return IPCResponse(success: true, command: message.command, data: ["items": items])

        case "getCredentials":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let idString: String = message.param("id"),
                  let id = UUID(uuidString: idString) else {
                return IPCResponse(success: false, command: message.command, error: "Invalid item ID")
            }

            guard let item = vaultManager.getItem(id: id),
                  let login = item as? LoginItem else {
                return IPCResponse(success: false, command: message.command, error: "Item not found")
            }

            var responseData: [String: Any] = [
                "username": login.username,
                "password": login.password
            ]

            // Include TOTP if available
            if let totpSecret = login.totpSecret, !totpSecret.isEmpty {
                let generator = TOTPGenerator()
                if let totp = try? generator.generate(secret: totpSecret) {
                    responseData["totp"] = totp.code
                    responseData["totpRemaining"] = totp.remainingSeconds
                    responseData["totpPeriod"] = totp.period
                }
            }

            return IPCResponse(
                success: true,
                command: message.command,
                data: responseData
            )

        case "getTOTP":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let idString: String = message.param("id"),
                  let id = UUID(uuidString: idString) else {
                return IPCResponse(success: false, command: message.command, error: "Invalid item ID")
            }

            guard let item = vaultManager.getItem(id: id),
                  let login = item as? LoginItem,
                  let totpSecret = login.totpSecret, !totpSecret.isEmpty else {
                return IPCResponse(success: false, command: message.command, error: "No TOTP configured")
            }

            let generator = TOTPGenerator()
            guard let totp = try? generator.generate(secret: totpSecret) else {
                return IPCResponse(success: false, command: message.command, error: "Invalid TOTP secret")
            }

            return IPCResponse(
                success: true,
                command: message.command,
                data: [
                    "code": totp.code,
                    "remaining": totp.remainingSeconds,
                    "period": totp.period
                ]
            )

        case "listForUrl":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let url: String = message.param("url") else {
                return IPCResponse(success: false, command: message.command, error: "Missing URL parameter")
            }

            let domain = extractDomain(from: url)
            let results = vaultManager.items.logins.filter { login in
                login.urls.contains { loginUrl in
                    extractDomain(from: loginUrl) == domain
                }
            }

            let items = results.map { login -> [String: Any] in
                [
                    "id": login.id.uuidString,
                    "title": login.title,
                    "username": login.username,
                    "url": login.urls.first ?? "",
                    "hasTotp": login.totpSecret != nil && !login.totpSecret!.isEmpty
                ]
            }

            return IPCResponse(success: true, command: message.command, data: ["items": items])

        case "lock":
            await vaultManager.lock()
            return IPCResponse(success: true, command: message.command, data: [:])

        case "unlock":
            guard let password: String = message.param("password") else {
                return IPCResponse(success: false, command: message.command, error: "Missing password")
            }

            do {
                try await vaultManager.unlock(password: password)
                return IPCResponse(success: true, command: message.command, data: [:])
            } catch {
                return IPCResponse(success: false, command: message.command, error: "Invalid password")
            }

        case "saveCredentials":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let url: String = message.param("url"),
                  let password: String = message.param("password") else {
                return IPCResponse(success: false, command: message.command, error: "Missing required parameters")
            }

            let username: String = message.param("username") ?? ""
            let title: String = message.param("title") ?? extractDomain(from: url)

            let login = LoginItem(
                title: title,
                username: username,
                password: password,
                urls: [url],
                notes: "Saved from browser extension"
            )

            do {
                try await vaultManager.addItem(login)
                return IPCResponse(success: true, command: message.command, data: ["id": login.id.uuidString])
            } catch {
                return IPCResponse(success: false, command: message.command, error: "Failed to save: \(error.localizedDescription)")
            }

        case "updateCredentials":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let idString: String = message.param("id"),
                  let id = UUID(uuidString: idString) else {
                return IPCResponse(success: false, command: message.command, error: "Invalid item ID")
            }

            guard let item = vaultManager.getItem(id: id),
                  var login = item as? LoginItem else {
                return IPCResponse(success: false, command: message.command, error: "Item not found")
            }

            // Update password if provided
            if let newPassword: String = message.param("password"), !newPassword.isEmpty {
                login.updatePassword(newPassword)
            }

            // Update username if provided
            if let newUsername: String = message.param("username") {
                login.username = newUsername
            }

            do {
                try await vaultManager.updateItem(login)
                return IPCResponse(success: true, command: message.command, data: ["id": login.id.uuidString])
            } catch {
                return IPCResponse(success: false, command: message.command, error: "Failed to update: \(error.localizedDescription)")
            }

        case "checkExisting":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let url: String = message.param("url") else {
                return IPCResponse(success: false, command: message.command, error: "Missing URL parameter")
            }

            let username: String = message.param("username") ?? ""
            let domain = extractDomain(from: url)

            // Find matching items
            let matching = vaultManager.items.logins.filter { login in
                login.urls.contains { loginUrl in
                    extractDomain(from: loginUrl) == domain
                } && login.username == username
            }

            if let existingLogin = matching.first {
                return IPCResponse(
                    success: true,
                    command: message.command,
                    data: [
                        "exists": true,
                        "id": existingLogin.id.uuidString,
                        "title": existingLogin.title
                    ]
                )
            } else {
                return IPCResponse(success: true, command: message.command, data: ["exists": false])
            }

        case "checkBreach":
            guard !vaultManager.isLocked else {
                return IPCResponse(success: false, command: message.command, error: "Vault is locked")
            }

            guard let password: String = message.param("password") else {
                return IPCResponse(success: false, command: message.command, error: "Missing password parameter")
            }

            do {
                let result = try await BreachChecker.shared.checkPassword(password)
                return IPCResponse(
                    success: true,
                    command: message.command,
                    data: [
                        "isBreached": result.isBreached,
                        "count": result.count
                    ]
                )
            } catch {
                return IPCResponse(success: false, command: message.command, error: "Breach check failed")
            }

        case "getPasswordStrength":
            guard let password: String = message.param("password") else {
                return IPCResponse(success: false, command: message.command, error: "Missing password parameter")
            }

            let score = BreachChecker.shared.calculatePasswordStrength(password)
            let level = BreachChecker.shared.strengthLevel(password)

            return IPCResponse(
                success: true,
                command: message.command,
                data: [
                    "score": score,
                    "level": level.rawValue
                ]
            )

        default:
            return IPCResponse(success: false, command: message.command, error: "Unknown command")
        }
    }

    private func extractDomain(from urlString: String) -> String {
        var urlStr = urlString.lowercased()
        if !urlStr.contains("://") {
            urlStr = "https://" + urlStr
        }

        guard let url = URL(string: urlStr),
              let host = url.host else {
            return urlString.lowercased()
        }

        // Remove www prefix
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }
}

// MARK: - IPC Message Types

struct IPCMessage: Codable {
    let command: String
    let params: [String: AnyCodable]?

    /// Get a parameter value by key.
    func param<T>(_ key: String) -> T? {
        return params?[key]?.value as? T
    }
}

struct IPCResponse: Codable {
    let success: Bool
    let command: String
    let data: [String: AnyCodable]?
    let error: String?

    init(success: Bool, command: String, data: [String: Any]? = nil, error: String? = nil) {
        self.success = success
        self.command = command
        self.data = data?.mapValues { AnyCodable($0) }
        self.error = error
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
