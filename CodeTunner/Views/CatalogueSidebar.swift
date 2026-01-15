//
//  CatalogueSidebar.swift
//  CodeTunner
//
//  A sidebar component for code snippets and SAS procedures
//  Copyright © 2025 SPU AI CLUB. All rights reserved.
//
//  Tirawat Nantamas | Dotmini Software | SPU AI CLUB
//

import SwiftUI

struct CatalogueItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let code: String
    let category: String
}

struct CatalogueSidebar: View {
    @EnvironmentObject var appState: AppState
    let onSelectItem: (String) -> Void
    
    @State private var selectedTab = 0 // 0: Snippets, 1: Procedures
    @State private var searchText = ""
    
    let snippets = [
        CatalogueItem(name: "Python HTTP Request", icon: "network", code: "import requests\nresponse = requests.get('https://api.github.com')\nprint(response.json())", category: "Python"),
        CatalogueItem(name: "SwiftUI List", icon: "list.bullet", code: "List(0..<10) { i in\n    Text(\"Item \\(i)\")\n}", category: "Swift"),
        CatalogueItem(name: "Rust File Write", icon: "doc.badge.plus", code: "use std::fs::File;\nuse std::io::prelude::*;\n\nfn main() -> std::io::Result<()> {\n    let mut file = File::create(\"hello.txt\")?;\n    file.write_all(b\"Hello, world!\")?;\n    Ok(())\n}", category: "Rust"),
        CatalogueItem(name: "React Component", icon: "atom", code: "import React from 'react';\n\nconst MyComponent = () => {\n  return <div>Hello World</div>;\n};\n\nexport default MyComponent;", category: "JS"),
        CatalogueItem(name: "SQL Create Table", icon: "table", code: "CREATE TABLE users (\n    id INTEGER PRIMARY KEY,\n    name TEXT NOT NULL,\n    email TEXT UNIQUE\n);", category: "SQL")
    ]
    
    let procedures = [
        CatalogueItem(name: "Data Cleaning", icon: "wand.and.stars", code: "# Data Cleaning Template\ndf = df.dropna()\ndf = df.drop_duplicates()\nprint('Cleaning complete')", category: "General"),
        CatalogueItem(name: "Feature Engineering", icon: "hammer", code: "# Feature Engineering Template\ndf['new_feature'] = df['a'] * df['b']\nprint('Feature engineered')", category: "ML"),
        CatalogueItem(name: "Model Training", icon: "cpu", code: "from sklearn.ensemble import RandomForestClassifier\nmodel = RandomForestClassifier()\nmodel.fit(X_train, y_train)\nprint('Model trained')", category: "ML"),
        CatalogueItem(name: "Visual Analysis", icon: "chart.bar", code: "import matplotlib.pyplot as plt\ndf.plot(kind='bar')\nplt.show()", category: "Viz")
    ]
    
    var filteredItems: [CatalogueItem] {
        let items = selectedTab == 0 ? snippets : procedures
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.category.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Catalogue")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Image(systemName: "book.fill")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .padding(10)
            
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Snippets").tag(0)
                Text("Procedures").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            
            Divider()
            
            // Items List
            List {
                ForEach(filteredItems) { item in
                    Button(action: { onSelectItem(item.code) }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(accentGradient(for: item.category))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: item.icon)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(item.category)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200, maxWidth: 300)
    }
    
    private func accentGradient(for category: String) -> LinearGradient {
        switch category {
        case "Python": return LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case "Swift": return LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
        case "Rust": return LinearGradient(colors: [.brown, .black], startPoint: .top, endPoint: .bottom)
        case "JS": return LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
        case "SQL": return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        case "ML": return LinearGradient(colors: [.purple, .indigo], startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [.gray, .secondary], startPoint: .top, endPoint: .bottom)
        }
    }
}
