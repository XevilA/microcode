//
//  ExportWindow.swift
//  CodeTunner
//
//  Created by SPU AI CLUB
//  Copyright © 2025 Dotmini Software. All rights reserved.
//

import SwiftUI

struct ExportWindow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var exportType: ExportType = .pdf
    @State private var targetLanguage: String = "python"
    @State private var filename: String = "export"
    @State private var useAIAnalysis: Bool = true
    @State private var autoRefactor: Bool = false
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""
    
    enum ExportType: String, CaseIterable {
        case pdf = "PDF Document"
        case translate = "Translate to Language"
    }
    
    var body: some View {
        ToolWindowWrapper(
            title: "Export Code",
            subtitle: "Convert or export source code",
            icon: "square.and.arrow.up",
            iconColor: .blue
        ) {
            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Export Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Type")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Type", selection: $exportType) {
                        ForEach(ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Export Options
                if exportType == .pdf {
                    pdfExportOptions
                } else {
                    translationOptions
                }
                
                // AI Analysis Options
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Use AI Analysis Before Export", isOn: $useAIAnalysis)
                        .font(.system(size: 13, weight: .medium))
                    
                    if useAIAnalysis {
                        Toggle("Auto-Refactor Code", isOn: $autoRefactor)
                            .font(.system(size: 12))
                            .padding(.leading, 20)
                        
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                                .font(.system(size: 11))
                            Text("AI will analyze complexity and code smells" + (autoRefactor ? " + refactor issues" : ""))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                
                // Filename
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filename")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Enter filename", text: $filename)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Messages
                if !successMessage.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        Text(successMessage)
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
                
                if !errorMessage.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 12))
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()
            }
            .padding()
        } footer: {
            HStack {
                Text(appState.currentFile?.name ?? "No file selected")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 8)
                }
                
                Button("Export") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing || filename.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private var pdfExportOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.richtext")
                    .foregroundColor(.red)
                Text("Export code with syntax highlighting to PDF")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var translationOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Language")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Picker("Language", selection: $targetLanguage) {
                Text("Python").tag("python")
                Text("Swift").tag("swift")
                Text("JavaScript").tag("javascript")
                Text("TypeScript").tag("typescript")
                Text("Rust").tag("rust")
                Text("Go").tag("go")
                Text("C#").tag("csharp")
                Text("Java").tag("java")
                Text("Kotlin").tag("kotlin")
                Text("C++").tag("cpp")
            }
            .pickerStyle(.menu)
            
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI will translate your code to \(targetLanguage)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func performExport() {
        guard let file = appState.currentFile else { return }
        
        isProcessing = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            do {
                let exporter = ExportService.shared
                var codeToExport = file.content
                var analysisMetrics: (complexity: Int, codeSmells: [CodeSmell]) = (0, [])
                var refactoredComplexity: Int? = nil
                
                // AI Analysis & Refactor if enabled
                if useAIAnalysis {
                    // Analyze code first
                    let analyzer = CodeAnalyzer.shared
                    let metrics = analyzer.analyzeComplexity(code: file.content, language: file.language)
                    analysisMetrics = (metrics.complexity, metrics.codeSmells)
                    
                    await MainActor.run {
                        successMessage = "Analyzing... Complexity: \(metrics.complexity), Smells: \(metrics.codeSmells.count)"
                    }
                    
                    // Auto-refactor if enabled and smells detected
                    if autoRefactor && !metrics.codeSmells.isEmpty {
                        let refactorInstructions = "Fix these issues: \(metrics.codeSmells.map { $0.type + " (line \($0.line))" }.joined(separator: ", ")). Maintain functionality."
                        
                        await MainActor.run {
                            successMessage = "Refactoring code..."
                        }
                        
                        let refactored = try await BackendService.shared.refactorCode(
                            code: file.content,
                            instructions: refactorInstructions,
                            provider: appState.aiProvider,
                            model: appState.aiModel,
                            apiKey: appState.apiKeys[appState.aiProvider] ?? ""
                        )
                        codeToExport = refactored
                        
                        // Analyze refactored code for report
                        let newMetrics = analyzer.analyzeComplexity(code: refactored, language: file.language)
                        refactoredComplexity = newMetrics.complexity
                    }
                }
                
                if exportType == .pdf {
                    // Create Report Data
                    let reportData = ReportData(
                        filename: filename,
                        language: file.language,
                        originalCode: file.content,
                        refactoredCode: (autoRefactor && analysisMetrics.codeSmells.count > 0) ? codeToExport : nil, // Only set if we actually refactored
                        complexityOp: analysisMetrics.complexity,
                        complexityNew: refactoredComplexity,
                        smells: analysisMetrics.codeSmells,
                        date: Date()
                    )
                    
                    let url = try exporter.exportRefactorReport(data: reportData)
                    
                    await MainActor.run {
                        let analysisText = useAIAnalysis ? (autoRefactor ? " (Enterprise Report Generated)" : " (Report Generated)") : ""
                        successMessage = "PDF exported\(analysisText): \(url.path)"
                        isProcessing = false
                    }
                } else {
                    let translated = try await exporter.translateCode(
                        code: codeToExport,
                        fromLanguage: file.language,
                        toLanguage: targetLanguage,
                        provider: appState.aiProvider,
                        model: appState.aiModel,
                        apiKey: appState.apiKeys[appState.aiProvider] ?? ""
                    )
                    
                    let url = try exporter.exportTranslatedCode(
                        translatedCode: translated,
                        toLanguage: targetLanguage,
                        filename: filename
                    )
                    
                    await MainActor.run {
                        let analysisText = useAIAnalysis ? (autoRefactor ? " (analyzed + refactored)" : " (analyzed)") : ""
                        successMessage = "Translated to \(targetLanguage)\(analysisText): \(url.path)"
                        isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Export failed: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}
