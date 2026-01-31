#!/usr/bin/env swift

import Foundation

// MARK: - Native Messaging Protocol

/// Reads a message from stdin using Chrome's native messaging protocol.
/// Message format: 4-byte length (little-endian) followed by JSON data.
func readMessage() -> [String: Any]? {
    let stdin = FileHandle.standardInput

    // Read 4-byte length prefix
    guard let lengthData = try? stdin.read(upToCount: 4),
          lengthData.count == 4 else {
        return nil
    }

    let length = lengthData.withUnsafeBytes { ptr in
        ptr.load(as: UInt32.self)
    }

    guard length > 0, length < 1024 * 1024 else {
        return nil
    }

    // Read message data
    guard let messageData = try? stdin.read(upToCount: Int(length)),
          messageData.count == Int(length) else {
        return nil
    }

    // Parse JSON
    guard let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
        return nil
    }

    return json
}

/// Writes a message to stdout using Chrome's native messaging protocol.
func writeMessage(_ message: [String: Any]) {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: message) else {
        return
    }

    let stdout = FileHandle.standardOutput

    // Write 4-byte length prefix (little-endian)
    var length = UInt32(jsonData.count)
    let lengthData = Data(bytes: &length, count: 4)

    try? stdout.write(contentsOf: lengthData)
    try? stdout.write(contentsOf: jsonData)
}

// MARK: - IPC Communication

/// Connects to DodoPass via Unix socket.
func connectToApp() -> FileHandle? {
    let socketPath = "/tmp/dodopass.sock"

    // Check if socket exists
    guard FileManager.default.fileExists(atPath: socketPath) else {
        return nil
    }

    // Create socket
    let socket = socket(AF_UNIX, SOCK_STREAM, 0)
    guard socket >= 0 else {
        return nil
    }

    // Connect to Unix socket
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)

    socketPath.withCString { ptr in
        withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
            let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
            strcpy(pathBuf, ptr)
        }
    }

    let result = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
            Darwin.connect(socket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    guard result == 0 else {
        close(socket)
        return nil
    }

    return FileHandle(fileDescriptor: socket, closeOnDealloc: true)
}

/// Sends a command to DodoPass and returns the response.
func sendToApp(_ command: [String: Any], requestId: Int?) -> [String: Any] {
    guard let handle = connectToApp() else {
        var response: [String: Any] = ["success": false, "error": "DodoPass is not running"]
        if let id = requestId {
            response["requestId"] = id
        }
        return response
    }

    defer {
        try? handle.close()
    }

    // Build IPC command (without requestId - that's for browser<->host only)
    var ipcCommand: [String: Any] = [:]
    if let cmd = command["command"] as? String {
        ipcCommand["command"] = cmd
    }
    if let params = command["params"] as? [String: Any] {
        ipcCommand["params"] = params
    }

    // Send command
    guard let jsonData = try? JSONSerialization.data(withJSONObject: ipcCommand) else {
        var response: [String: Any] = ["success": false, "error": "Invalid command"]
        if let id = requestId {
            response["requestId"] = id
        }
        return response
    }

    try? handle.write(contentsOf: jsonData)

    // Read response
    let responseData = handle.availableData

    guard !responseData.isEmpty else {
        var response: [String: Any] = ["success": false, "error": "No response from DodoPass"]
        if let id = requestId {
            response["requestId"] = id
        }
        return response
    }

    guard var response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
        var response: [String: Any] = ["success": false, "error": "Invalid response from DodoPass"]
        if let id = requestId {
            response["requestId"] = id
        }
        return response
    }

    // Add requestId to response so browser can match it
    if let id = requestId {
        response["requestId"] = id
    }

    return response
}

// MARK: - Main Loop

func main() {
    // Process messages in a loop
    while true {
        guard let message = readMessage() else {
            break
        }

        // Extract requestId from browser message
        let requestId = message["requestId"] as? Int

        // Forward to DodoPass app and get response with requestId preserved
        let response = sendToApp(message, requestId: requestId)
        writeMessage(response)
    }
}

// Run
main()
