import SwiftUI

struct LibraryView: View {
    @StateObject private var ragStore = RAGStore()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                
                List(ragStore.filteredSnippets(for: searchText)) { snippet in
                    EvidenceRow(snippet: snippet)
                }
            }
            .navigationTitle("Evidence Library")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search evidence...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
}

struct EvidenceRow: View {
    let snippet: EvidenceSnippet
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snippet.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(snippet.snippet)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.secondary)
            
            HStack {
                Text(snippet.source)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button("Why?") {
                    showingDetail = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetail) {
            EvidenceDetailView(snippet: snippet)
        }
    }
}

struct EvidenceDetailView: View {
    let snippet: EvidenceSnippet
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(snippet.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(snippet.snippet)
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.headline)
                        Text(snippet.source)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("This information is for educational purposes. Consult your healthcare provider for personalized advice.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EvidenceSnippet: Identifiable {
    let id: String
    let title: String
    let snippet: String
    let source: String
}

class RAGStore: ObservableObject {
    @Published var snippets: [EvidenceSnippet] = []
    
    init() {
        loadSnippets()
    }
    
    private func loadSnippets() {
        // Load from rag_index.json
        guard let url = Bundle.main.url(forResource: "rag_index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            loadMockSnippets()
            return
        }
        
        snippets = jsonArray.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let snippet = dict["snippet"] as? String,
                  let source = dict["source"] as? String else {
                return nil
            }
            
            return EvidenceSnippet(id: id, title: title, snippet: snippet, source: source)
        }
    }
    
    private func loadMockSnippets() {
        snippets = [
            EvidenceSnippet(
                id: "MOCK-001",
                title: "Exercise Benefits for Low Back Pain",
                snippet: "Regular exercise helps reduce low back pain and improve function. Focus on gentle movements within comfortable limits.",
                source: "Clinical Guidelines"
            ),
            EvidenceSnippet(
                id: "MOCK-002",
                title: "Range of Motion Importance",
                snippet: "Maintaining joint range of motion prevents stiffness and supports daily activities. Move joints through their available range regularly.",
                source: "Physical Therapy Research"
            )
        ]
    }
    
    func filteredSnippets(for searchText: String) -> [EvidenceSnippet] {
        if searchText.isEmpty {
            return snippets
        }
        
        return snippets.filter { snippet in
            snippet.title.localizedCaseInsensitiveContains(searchText) ||
            snippet.snippet.localizedCaseInsensitiveContains(searchText) ||
            snippet.source.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    LibraryView()
}
