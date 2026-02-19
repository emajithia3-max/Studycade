import StoreKit
import Foundation

actor StoreManager: ObservableObject {
    @Published private(set) var subscriptionGroupStatus: RenewalState = .unknown
    @Published private(set) var hasPro: Bool = false

    private var updateListenerTask: Task<Void, Never>? = nil

    nonisolated private let proProductID = "com.studyarcade.pro.monthly"

    init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func fetchAvailableProducts() async throws -> [Product] {
        let allProducts = try await Product.products(for: [proProductID])
        return allProducts
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.updateSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    nonisolated private func updateSubscriptionStatus() async {
        do {
            if case .verified(let transaction) = try await Transaction.latest(of: proProductID) {
                await MainActor.run {
                    self.hasPro = true
                }
            } else {
                await MainActor.run {
                    self.hasPro = false
                }
            }
        } catch {
            await MainActor.run {
                self.hasPro = false
            }
        }
    }

    var canCreateMoreStudySets: Bool {
        hasPro
    }

    var dailyXPLimit: Int {
        hasPro ? .max : 500
    }

    var canPlayAllGames: Bool {
        hasPro
    }
}

enum RenewalState {
    case unknown
    case subscribed
    case expired
    case revoked
}

enum StoreError: Error {
    case failedVerification
}
