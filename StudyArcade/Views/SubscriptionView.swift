import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var storeManager: StoreManager
    @State private var products: [String] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text("Upgrade to Pro")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 32)

                VStack(spacing: 16) {
                    FeatureRow(icon: "infinity", title: "Unlimited Study Sets", subtitle: "Create as many study sets as you want")
                    FeatureRow(icon: "bolt.fill", title: "No Daily XP Cap", subtitle: "Earn unlimited XP daily")
                    FeatureRow(icon: "gamecontroller.fill", title: "All Games Unlocked", subtitle: "Access to all arcade minigames")
                    FeatureRow(icon: "star.fill", title: "Pro Features", subtitle: "Advanced analytics and stats")
                }
                .padding(16)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await purchaseSubscription()
                        }
                    }) {
                        Text("Subscribe - $9.99/month")
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .fontWeight(.bold)
                    }

                    Button(action: { }) {
                        Text("Restore Purchases")
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.black.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(16)
            }
            .padding(16)
        }
        .navigationTitle("Pro Subscription")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func purchaseSubscription() async {
        isLoading = true
        do {
            let products = try await storeManager.fetchAvailableProducts()
            if let proProduct = products.first {
                _ = try await storeManager.purchase(proProduct)
            }
        } catch {
            print("Purchase error: \(error)")
        }
        isLoading = false
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        SubscriptionView()
            .environmentObject(StoreManager())
    }
}
