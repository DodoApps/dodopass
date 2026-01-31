import Foundation

/// Resolves sync conflicts between vault versions.
final class ConflictResolver: Sendable {
    // MARK: - Singleton

    static let shared = ConflictResolver()

    // MARK: - Types

    struct ConflictInfo {
        let localVersion: VaultMetadata
        let remoteVersion: VaultMetadata
        let localItems: VaultItems
        let remoteItems: VaultItems
        let conflictingItems: [ConflictingItem]
    }

    struct ConflictingItem {
        let id: UUID
        let localItem: (any VaultItem)?
        let remoteItem: (any VaultItem)?
        let conflictType: ConflictType
    }

    enum ConflictType {
        case addedBoth         // Same item added in both places
        case modifiedBoth      // Same item modified in both places
        case deletedLocal      // Deleted locally, modified remotely
        case deletedRemote     // Modified locally, deleted remotely
    }

    struct MergeResult {
        let mergedItems: VaultItems
        let mergedMetadata: VaultMetadata
        let conflicts: [UnresolvedConflict]
    }

    struct UnresolvedConflict {
        let itemID: UUID
        let localTitle: String
        let remoteTitle: String
        let reason: String
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Conflict Detection

    /// Detect conflicts between local and remote versions.
    func detectConflicts(
        local: (metadata: VaultMetadata, items: VaultItems),
        remote: (metadata: VaultMetadata, items: VaultItems)
    ) -> ConflictInfo {
        var conflicts: [ConflictingItem] = []

        let localItemsDict = Dictionary(uniqueKeysWithValues: local.items.allItems.map { ($0.id, $0) })
        let remoteItemsDict = Dictionary(uniqueKeysWithValues: remote.items.allItems.map { ($0.id, $0) })

        let allIDs = Set(localItemsDict.keys).union(Set(remoteItemsDict.keys))

        for id in allIDs {
            let localItem = localItemsDict[id]
            let remoteItem = remoteItemsDict[id]

            if let local = localItem, let remote = remoteItem {
                // Both have the item
                if local.modifiedAt != remote.modifiedAt {
                    conflicts.append(ConflictingItem(
                        id: id,
                        localItem: local,
                        remoteItem: remote,
                        conflictType: .modifiedBoth
                    ))
                }
            } else if localItem != nil && remoteItem == nil {
                // Check if it was deleted remotely or added locally
                if wasItemInPreviousSync(id: id, metadata: remote.metadata) {
                    conflicts.append(ConflictingItem(
                        id: id,
                        localItem: localItem,
                        remoteItem: nil,
                        conflictType: .deletedRemote
                    ))
                }
                // Otherwise it was just added locally, no conflict
            } else if localItem == nil && remoteItem != nil {
                // Check if it was deleted locally or added remotely
                if wasItemInPreviousSync(id: id, metadata: local.metadata) {
                    conflicts.append(ConflictingItem(
                        id: id,
                        localItem: nil,
                        remoteItem: remoteItem,
                        conflictType: .deletedLocal
                    ))
                }
                // Otherwise it was just added remotely, no conflict
            }
        }

        return ConflictInfo(
            localVersion: local.metadata,
            remoteVersion: remote.metadata,
            localItems: local.items,
            remoteItems: remote.items,
            conflictingItems: conflicts
        )
    }

    // MARK: - Merge Strategies

    /// Merge using "last write wins" strategy.
    func mergeLastWriteWins(
        local: (metadata: VaultMetadata, items: VaultItems),
        remote: (metadata: VaultMetadata, items: VaultItems)
    ) -> MergeResult {
        var mergedItems: [any VaultItem] = []

        let localItemsDict = Dictionary(uniqueKeysWithValues: local.items.allItems.map { ($0.id, $0) })
        let remoteItemsDict = Dictionary(uniqueKeysWithValues: remote.items.allItems.map { ($0.id, $0) })

        let allIDs = Set(localItemsDict.keys).union(Set(remoteItemsDict.keys))

        for id in allIDs {
            let localItem = localItemsDict[id]
            let remoteItem = remoteItemsDict[id]

            if let local = localItem, let remote = remoteItem {
                // Take the newer one
                if local.modifiedAt >= remote.modifiedAt {
                    mergedItems.append(local)
                } else {
                    mergedItems.append(remote)
                }
            } else if let local = localItem {
                mergedItems.append(local)
            } else if let remote = remoteItem {
                mergedItems.append(remote)
            }
        }

        // Create merged metadata
        var mergedMetadata = VaultMetadata(
            name: local.metadata.name,
            createdAt: min(local.metadata.createdAt, remote.metadata.createdAt),
            modifiedAt: Date(),
            vaultId: local.metadata.vaultId
        )
        mergedMetadata.mergeVersionVector(with: remote.metadata)

        // Create merged vault items
        var resultItems = VaultItems()
        for item in mergedItems {
            resultItems.addItem(item)
        }

        return MergeResult(
            mergedItems: resultItems,
            mergedMetadata: mergedMetadata,
            conflicts: []
        )
    }

    /// Merge keeping both versions for conflicts.
    func mergeKeepBoth(
        local: (metadata: VaultMetadata, items: VaultItems),
        remote: (metadata: VaultMetadata, items: VaultItems)
    ) -> MergeResult {
        var mergedItems: [any VaultItem] = []

        let localItemsDict = Dictionary(uniqueKeysWithValues: local.items.allItems.map { ($0.id, $0) })
        let remoteItemsDict = Dictionary(uniqueKeysWithValues: remote.items.allItems.map { ($0.id, $0) })

        let allIDs = Set(localItemsDict.keys).union(Set(remoteItemsDict.keys))

        for id in allIDs {
            let localItem = localItemsDict[id]
            let remoteItem = remoteItemsDict[id]

            if let local = localItem, let remote = remoteItem {
                // Keep both if they differ
                if local.modifiedAt != remote.modifiedAt {
                    mergedItems.append(local)
                    // For conflict copies, we keep the remote as-is
                    // The caller can rename it if needed
                    mergedItems.append(remote)
                } else {
                    mergedItems.append(local)
                }
            } else if let local = localItem {
                mergedItems.append(local)
            } else if let remote = remoteItem {
                mergedItems.append(remote)
            }
        }

        var mergedMetadata = VaultMetadata(
            name: local.metadata.name,
            createdAt: min(local.metadata.createdAt, remote.metadata.createdAt),
            modifiedAt: Date(),
            vaultId: local.metadata.vaultId
        )
        mergedMetadata.mergeVersionVector(with: remote.metadata)

        // Create merged vault items
        var resultItems = VaultItems()
        for item in mergedItems {
            resultItems.addItem(item)
        }

        return MergeResult(
            mergedItems: resultItems,
            mergedMetadata: mergedMetadata,
            conflicts: []
        )
    }

    // MARK: - Private Helpers

    private func wasItemInPreviousSync(id: UUID, metadata: VaultMetadata) -> Bool {
        // This would ideally check a sync history, but for simplicity
        // we assume items were in previous sync if the vault isn't new
        return metadata.modifiedAt > metadata.createdAt
    }
}
