import Foundation

/// Handles serialization and deserialization of the vault file format.
///
/// File Format:
/// ```
/// [4 bytes: magic "DODO"]
/// [4 bytes: format version (UInt32, little-endian)]
/// [32 bytes: salt]
/// [N bytes: encrypted verifier (length-prefixed)]
/// [N bytes: encrypted metadata JSON (length-prefixed)]
/// [N bytes: encrypted items blob (length-prefixed)]
/// ```
enum VaultFormat {
    // MARK: - Errors

    enum FormatError: LocalizedError {
        case invalidMagic
        case unsupportedVersion(version: UInt32)
        case invalidData
        case insufficientData
        case serializationFailed(underlying: Error?)
        case deserializationFailed(underlying: Error?)

        var errorDescription: String? {
            switch self {
            case .invalidMagic:
                return "Not a valid DodoPass vault file"
            case .unsupportedVersion(let version):
                return "Unsupported vault version: \(version)"
            case .invalidData:
                return "Invalid vault data"
            case .insufficientData:
                return "Vault file is truncated or corrupted"
            case .serializationFailed(let error):
                return "Failed to serialize vault: \(error?.localizedDescription ?? "Unknown error")"
            case .deserializationFailed(let error):
                return "Failed to deserialize vault: \(error?.localizedDescription ?? "Unknown error")"
            }
        }
    }

    // MARK: - Vault Container

    /// Container for the raw vault file data.
    struct VaultContainer {
        let version: UInt32
        let salt: Data
        let encryptedVerifier: Data
        let encryptedMetadata: Data
        let encryptedItems: Data
    }

    // MARK: - Encoding

    /// Encodes a vault container to raw data.
    /// - Parameter container: The vault container to encode.
    /// - Returns: The encoded data.
    static func encode(_ container: VaultContainer) throws -> Data {
        var data = Data()

        // Magic bytes
        data.append(CryptoConstants.vaultMagic)

        // Version
        var version = container.version.littleEndian
        data.append(Data(bytes: &version, count: 4))

        // Salt (fixed 32 bytes)
        guard container.salt.count == CryptoConstants.saltLength else {
            throw FormatError.invalidData
        }
        data.append(container.salt)

        // Encrypted verifier (length-prefixed)
        data.append(contentsOf: lengthPrefix(container.encryptedVerifier))

        // Encrypted metadata (length-prefixed)
        data.append(contentsOf: lengthPrefix(container.encryptedMetadata))

        // Encrypted items (length-prefixed)
        data.append(contentsOf: lengthPrefix(container.encryptedItems))

        return data
    }

    /// Decodes raw data to a vault container.
    /// - Parameter data: The raw data to decode.
    /// - Returns: The decoded vault container.
    static func decode(_ data: Data) throws -> VaultContainer {
        var offset = 0

        // Validate minimum size
        let headerSize = 4 + 4 + CryptoConstants.saltLength // magic + version + salt
        guard data.count >= headerSize else {
            throw FormatError.insufficientData
        }

        // Check magic bytes
        let magic = data[offset..<offset + 4]
        guard magic == CryptoConstants.vaultMagic else {
            throw FormatError.invalidMagic
        }
        offset += 4

        // Read version
        let versionBytes = data[offset..<offset + 4]
        let version = versionBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
        guard version <= CryptoConstants.currentFormatVersion else {
            throw FormatError.unsupportedVersion(version: version)
        }
        offset += 4

        // Read salt
        let salt = data[offset..<offset + CryptoConstants.saltLength]
        offset += CryptoConstants.saltLength

        // Read encrypted verifier
        let (verifier, verifierBytesRead) = try readLengthPrefixed(from: data, at: offset)
        offset += verifierBytesRead

        // Read encrypted metadata
        let (metadata, metadataBytesRead) = try readLengthPrefixed(from: data, at: offset)
        offset += metadataBytesRead

        // Read encrypted items
        let (items, _) = try readLengthPrefixed(from: data, at: offset)

        return VaultContainer(
            version: version,
            salt: Data(salt),
            encryptedVerifier: verifier,
            encryptedMetadata: metadata,
            encryptedItems: items
        )
    }

    // MARK: - Length Prefixing

    /// Adds a 4-byte length prefix to data.
    private static func lengthPrefix(_ data: Data) -> Data {
        var length = UInt32(data.count).littleEndian
        var prefixed = Data(bytes: &length, count: 4)
        prefixed.append(data)
        return prefixed
    }

    /// Reads length-prefixed data from a buffer.
    private static func readLengthPrefixed(from data: Data, at offset: Int) throws -> (Data, Int) {
        guard offset + 4 <= data.count else {
            throw FormatError.insufficientData
        }

        let lengthBytes = data[offset..<offset + 4]
        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

        let dataStart = offset + 4
        let dataEnd = dataStart + Int(length)

        guard dataEnd <= data.count else {
            throw FormatError.insufficientData
        }

        return (Data(data[dataStart..<dataEnd]), 4 + Int(length))
    }

    // MARK: - Content Serialization

    /// Serializes vault items to JSON data.
    /// - Parameter items: The items to serialize.
    /// - Returns: JSON-encoded data.
    static func serializeItems(_ items: VaultItems) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        do {
            return try encoder.encode(items)
        } catch {
            throw FormatError.serializationFailed(underlying: error)
        }
    }

    /// Deserializes vault items from JSON data.
    /// - Parameter data: The JSON data to deserialize.
    /// - Returns: The deserialized items.
    static func deserializeItems(_ data: Data) throws -> VaultItems {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(VaultItems.self, from: data)
        } catch {
            throw FormatError.deserializationFailed(underlying: error)
        }
    }

    /// Serializes vault metadata to JSON data.
    /// - Parameter metadata: The metadata to serialize.
    /// - Returns: JSON-encoded data.
    static func serializeMetadata(_ metadata: VaultMetadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys

        do {
            return try encoder.encode(metadata)
        } catch {
            throw FormatError.serializationFailed(underlying: error)
        }
    }

    /// Deserializes vault metadata from JSON data.
    /// - Parameter data: The JSON data to deserialize.
    /// - Returns: The deserialized metadata.
    static func deserializeMetadata(_ data: Data) throws -> VaultMetadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(VaultMetadata.self, from: data)
        } catch {
            throw FormatError.deserializationFailed(underlying: error)
        }
    }
}
