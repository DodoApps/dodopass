import Foundation

/// In-memory search index for vault items.
/// Never persists plaintext data to disk.
final class SearchIndex: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = SearchIndex()

    // MARK: - Types

    private struct IndexedItem {
        let id: UUID
        let tokens: Set<String>
        let category: ItemCategory
        let title: String
        let isFavorite: Bool
        let modifiedAt: Date
    }

    // MARK: - Private State

    private var indexedItems: [UUID: IndexedItem] = [:]
    private var tokenIndex: [String: Set<UUID>] = [:]
    private var storedItems: [UUID: any VaultItem] = [:]
    private let queue = DispatchQueue(label: "com.dodopass.searchindex", attributes: .concurrent)

    // MARK: - Initialization

    init() {}

    // MARK: - Index Management

    /// Indexes a collection of items (alias for rebuildIndex).
    func indexItems(_ items: [any VaultItem]) {
        rebuildIndex(with: items)
    }

    /// Indexes a single item (alias for updateItem).
    func indexItem(_ item: any VaultItem) {
        updateItem(item)
    }

    /// Rebuilds the entire search index with new items.
    func rebuildIndex(with items: [any VaultItem]) {
        queue.async(flags: .barrier) { [weak self] in
            self?.indexedItems.removeAll()
            self?.tokenIndex.removeAll()

            for item in items {
                self?.addToIndex(item)
            }
        }
    }

    /// Adds or updates a single item in the index.
    func updateItem(_ item: any VaultItem) {
        queue.async(flags: .barrier) { [weak self] in
            self?.removeFromIndex(id: item.id)
            self?.addToIndex(item)
        }
    }

    /// Removes an item from the index.
    func removeItem(id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?.removeFromIndex(id: id)
        }
    }

    /// Clears all indexed data (called on vault lock).
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.indexedItems.removeAll()
            self?.tokenIndex.removeAll()
            self?.storedItems.removeAll()
        }
    }

    // MARK: - Search

    /// Searches the index with a query string.
    /// Returns items matching all tokens (AND logic).
    func search(query: String, limit: Int = 50) -> [any VaultItem] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        var matchingIDs: Set<UUID>?

        queue.sync {
            for token in queryTokens {
                // Find all IDs matching this token (prefix matching)
                var tokenMatches = Set<UUID>()

                for (indexedToken, ids) in tokenIndex {
                    if indexedToken.hasPrefix(token) {
                        tokenMatches.formUnion(ids)
                    }
                }

                if matchingIDs == nil {
                    matchingIDs = tokenMatches
                } else {
                    matchingIDs?.formIntersection(tokenMatches)
                }

                // Early exit if no matches
                if matchingIDs?.isEmpty == true {
                    break
                }
            }
        }

        guard let ids = matchingIDs, !ids.isEmpty else { return [] }

        // Score and sort results
        return scoreAndSort(ids: ids, queryTokens: queryTokens, limit: limit)
    }

    // MARK: - Private Helpers

    private func addToIndex(_ item: any VaultItem) {
        let tokens = generateTokens(for: item)

        let indexed = IndexedItem(
            id: item.id,
            tokens: tokens,
            category: item.category,
            title: item.title,
            isFavorite: item.favorite,
            modifiedAt: item.modifiedAt
        )

        indexedItems[item.id] = indexed
        storedItems[item.id] = item

        for token in tokens {
            tokenIndex[token, default: Set()].insert(item.id)
        }
    }

    private func removeFromIndex(id: UUID) {
        guard let indexed = indexedItems.removeValue(forKey: id) else { return }

        storedItems.removeValue(forKey: id)

        for token in indexed.tokens {
            tokenIndex[token]?.remove(id)
            if tokenIndex[token]?.isEmpty == true {
                tokenIndex.removeValue(forKey: token)
            }
        }
    }

    private func generateTokens(for item: any VaultItem) -> Set<String> {
        var tokens = Set<String>()

        // Title tokens
        tokens.formUnion(tokenize(item.title))

        // Tags
        for tag in item.tags {
            tokens.formUnion(tokenize(tag))
        }

        // Notes
        tokens.formUnion(tokenize(item.notes))

        // Category-specific tokens
        if let login = item as? LoginItem {
            tokens.formUnion(tokenize(login.username))
            for url in login.urls {
                tokens.formUnion(tokenizeURL(url))
            }
        } else if let card = item as? CreditCard {
            tokens.formUnion(tokenize(card.cardholderName))
            // Only index last 4 digits for security
            if card.cardNumber.count >= 4 {
                tokens.insert(String(card.cardNumber.suffix(4)))
            }
        } else if let identity = item as? Identity {
            tokens.formUnion(tokenize(identity.firstName))
            tokens.formUnion(tokenize(identity.lastName))
            tokens.formUnion(tokenize(identity.email))
        }

        return tokens
    }

    private func tokenize(_ text: String) -> Set<String> {
        let normalized = text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        // Split on word boundaries and non-alphanumeric characters
        let components = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 2 }

        return Set(components)
    }

    private func tokenizeURL(_ urlString: String) -> Set<String> {
        guard let url = URL(string: urlString) else {
            return tokenize(urlString)
        }

        var tokens = Set<String>()

        // Domain parts
        if let host = url.host {
            let domainParts = host.components(separatedBy: ".")
            for part in domainParts {
                if part.count >= 2 && part != "www" && part != "com" && part != "org" && part != "net" {
                    tokens.insert(part.lowercased())
                }
            }
        }

        // Path tokens
        tokens.formUnion(tokenize(url.path))

        return tokens
    }

    private func scoreAndSort(ids: Set<UUID>, queryTokens: Set<String>, limit: Int) -> [any VaultItem] {
        var scoredItems: [(id: UUID, score: Double)] = []

        for id in ids {
            guard let indexed = indexedItems[id] else { continue }

            var score: Double = 0

            // Exact title match bonus
            let titleTokens = tokenize(indexed.title)
            let titleMatchCount = queryTokens.intersection(titleTokens).count
            score += Double(titleMatchCount) * 10

            // Title starts with query bonus
            if indexed.title.lowercased().hasPrefix(queryTokens.first ?? "") {
                score += 20
            }

            // Favorite bonus
            if indexed.isFavorite {
                score += 5
            }

            // Recency bonus (items modified in last 30 days)
            let daysSinceModified = Date().timeIntervalSince(indexed.modifiedAt) / 86400
            if daysSinceModified < 30 {
                score += (30 - daysSinceModified) / 3
            }

            // Token overlap ratio
            let overlapRatio = Double(queryTokens.intersection(indexed.tokens).count) / Double(queryTokens.count)
            score += overlapRatio * 5

            scoredItems.append((id, score))
        }

        // Sort by score descending
        scoredItems.sort { $0.score > $1.score }

        // Return limited results
        let topIDs = scoredItems.prefix(limit).map(\.id)

        // Convert back to VaultItem objects using stored items
        var results: [any VaultItem] = []
        for id in topIDs {
            if let item = storedItems[id] {
                results.append(item)
            }
        }
        return results
    }
}
