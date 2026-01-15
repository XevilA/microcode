//
//  APIClientView.swift
//  CodeTunner
//
//  Created by SPU AI CLUB
//  Copyright © 2024 AIPRENEUR. All rights reserved.
//

import SwiftUI

struct APIClientView: View {
    @StateObject private var service = APIClientService.shared
    
    @State private var method: HTTPMethod = .get
    @State private var url: String = "https://httpbin.org/get"
    @State private var requestBody: String = "{\n  \"key\": \"value\"\n}"
    @State private var headers: [HeaderItem] = [HeaderItem(key: "Content-Type", value: "application/json")]
    @State private var selectedTab: Int = 0 // 0: Body, 1: Headers
    
    var body: some View {
        CompatHSplitView {
            // Sidebar (History/Collections placeholder)
            VStack {
                Text("History")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                
                List {
                    Label("GET httpbin.org", systemImage: "clock")
                    Label("POST api.example.com", systemImage: "clock")
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Main Area
            VStack(spacing: 0) {
                // Request Bar
                HStack(spacing: 8) {
                    Picker("", selection: $method) {
                        ForEach(HTTPMethod.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .frame(width: 100)
                    
                    TextField("Enter request URL", text: $url)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: sendRequest) {
                        HStack {
                            if service.isLoading {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Send")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(service.isLoading)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                
                // Request Config Tabs
                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text("Body").tag(0)
                        Text("Headers").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider().padding(.top, 8)
                    
                    if selectedTab == 0 {
                        TextEditor(text: $requestBody)
                            .font(.system(.body, design: .monospaced))
                            .padding(4)
                    } else {
                        List {
                            ForEach($headers) { $item in
                                HStack {
                                    TextField("Key", text: $item.key)
                                    TextField("Value", text: $item.value)
                                    Button(action: {
                                        if let idx = headers.firstIndex(where: { $0.id == item.id }) {
                                            headers.remove(at: idx)
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            Button("Add Header") {
                                headers.append(HeaderItem(key: "", value: ""))
                            }
                        }
                    }
                }
                .frame(height: 200)
                
                Divider()
                
                // Response Area
                VStack(spacing: 0) {
                    HStack {
                        Text("Response")
                            .font(.headline)
                        
                        Spacer()
                        
                        if let resp = service.lastResponse {
                            HStack(spacing: 12) {
                                Text("\(resp.status) \(resp.status == 200 ? "OK" : "")")
                                    .foregroundColor(resp.status >= 200 && resp.status < 300 ? .green : .red)
                                    .fontWeight(.bold)
                                
                                Text("\(resp.duration_ms) ms")
                                    .foregroundColor(.secondary)
                                
                                Text("\(resp.body.count) bytes")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    if let resp = service.lastResponse {
                        ScrollView {
                            Text(resp.body)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                    } else if let error = service.error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Send a request to see the response")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private func sendRequest() {
        Task {
            var headerDict: [String: String] = [:]
            for item in headers where !item.key.isEmpty {
                headerDict[item.key] = item.value
            }
            
            let req = APIRequest(
                method: method.rawValue,
                url: url,
                headers: headerDict,
                body: method == .get ? nil : requestBody
            )
            
            _ = try? await service.execute(req)
        }
    }
}

struct HeaderItem: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}
