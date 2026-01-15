//
//  PlaygroundCellView.swift
//  CodeTunner
//
//  Individual cell view for Playground Cell Mode
//  Copyright © 2025 SPU AI CLUB. All rights reserved.
//
//  Tirawat Nantamas | Dotmini Software | SPU AI CLUB
//

import SwiftUI

struct PlaygroundCellView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cell: PlaygroundCellModel
    let language: String
    let onRun: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    init(cell: PlaygroundCellModel, language: String, onRun: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.cell = cell
        self.language = language
        self.onRun = onRun
        self.onDelete = onDelete
    }
    
    private var cellBackground: Color {
        cell.colorTheme == .none ? 
            (appState.appTheme.isDark ? Color.black.opacity(0.2) : Color.white.opacity(0.5)) : 
            cell.colorTheme.color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(cell.colorTheme.iconColor)
                        .font(.system(size: 8))
                    
                    Text(cell.colorTheme == .none ? "Standard Cell" : "\(cell.colorTheme.rawValue) Cell")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isHovering {
                    HStack(spacing: 12) {
                        // Color Picker Menu
                        Menu {
                            ForEach(CellColorTheme.allCases) { theme in
                                Button(action: { cell.colorTheme = theme }) {
                                    Label(theme.rawValue, systemImage: theme == cell.colorTheme ? "checkmark" : "circle.fill")
                                        .foregroundColor(theme.iconColor)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 20)
                        
                        Button(action: onRun) {
                            Image(systemName: cell.isExecuting ? "stop.fill" : "play.fill")
                                .font(.system(size: 12))
                                .foregroundColor(cell.isExecuting ? .red : .green)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
                
                if cell.isExecuting {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(cellBackground.opacity(0.5))
            
            // Code Editor
            let lineCount = max(1, cell.code.components(separatedBy: "\n").count)
            let calculatedHeight = CGFloat(lineCount) * 20 + 24
            
            SyntaxHighlightedCodeView(
                text: $cell.code,
                language: language,
                fontSize: appState.playgroundFontSize,
                isDark: appState.appTheme.isDark,
                themeName: appState.appTheme.rawValue,
                fontName: appState.playgroundFontName,
                fontWeight: appState.playgroundFontWeight
            )
            .frame(height: max(60, min(calculatedHeight, 600)))
            .padding(.horizontal, 4)
            
            // Output
            if !cell.output.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "terminal")
                            .font(.system(size: 10))
                        Text("Output")
                            .font(.system(size: 10, weight: .bold))
                        
                        if cell.executionTime > 0 {
                            Spacer()
                            Text("\(String(format: "%.2f", cell.executionTime))s")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    
                    Text(cell.output)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(Color.black.opacity(0.05))
            }
        }
        .background(cellBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cell.colorTheme.borderColor.opacity(0.3), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
