import SwiftUI

struct Product: Identifiable {
    let id: Int
    let name: String
    let price: Double
    let icon: String
    let color: Color
}

let products = [
    Product(id: 1, name: "Headphones", price: 199, icon: "headphones", color: .indigo),
    Product(id: 2, name: "Camera", price: 649, icon: "camera", color: .orange),
    Product(id: 3, name: "Watch", price: 399, icon: "clock", color: .pink),
    Product(id: 4, name: "Speaker", price: 99, icon: "speaker.wave.2", color: .teal),
    Product(id: 5, name: "Laptop", price: 1299, icon: "laptopcomputer", color: .blue),
    Product(id: 6, name: "Gift Card", price: 50, icon: "gift", color: .green),
]

struct ShopView: View {
    @State private var cart: [Int] = []

    var total: Double {
        cart.compactMap { id in products.first { $0.id == id }?.price }.reduce(0, +)
    }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(products) { p in
                            ProductCard(product: p, count: cart.filter { $0 == p.id }.count) {
                                cart.append(p.id)
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Shop")
            }
            .tabItem { Label("Shop", systemImage: "bag") }

            NavigationStack {
                List {
                    if cart.isEmpty {
                        Text("Your cart is empty").foregroundStyle(.secondary)
                    }
                    ForEach(products.filter { cart.contains($0.id) }) { p in
                        HStack {
                            Image(systemName: p.icon).foregroundStyle(p.color)
                            Text(p.name)
                            Spacer()
                            Text("×\(cart.filter { $0 == p.id }.count)").foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            Text(String(format: "$%.2f", total)).font(.headline)
                        }
                        Button("Clear cart", role: .destructive) { cart.removeAll() }
                    }
                }
                .navigationTitle("Cart")
            }
            .tabItem { Label("Cart", systemImage: "cart") }
            .badge(cart.count)
        }
    }
}

struct ProductCard: View {
    let product: Product
    let count: Int
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(product.color.gradient)
                .frame(height: 110)
                .overlay(Image(systemName: product.icon).font(.system(size: 40)).foregroundStyle(.white))
            Text(product.name).font(.headline)
            HStack {
                Text(String(format: "$%.0f", product.price)).foregroundStyle(.secondary)
                Spacer()
                Button(action: onAdd) {
                    Text(count > 0 ? "\(count) in cart" : "Add")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Shop") {
    ShopView()
}
