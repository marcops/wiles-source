import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    overviewSection
                    sidebarSection
                    navigationModesSection
                    shortcutsSection
                }
                .padding(20)
            }
            Divider()
            footerView
        }
        .frame(width: 580, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Wiles File Manager")
                    .font(.system(size: 16, weight: .bold))
                Text("Help & Keyboard Shortcuts Cheatsheet")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overview")
                .font(.system(size: 14, weight: .semibold))
            Text("Wiles is a fast, native macOS file manager designed to bridge the best of GNOME Files (Nautilus) and macOS Finder. It supports instant directory navigation, flexible sidebar views, search, quick look, and customizable shortcut profiles.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var sidebarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sidebar & Favorites")
                .font(.system(size: 14, weight: .semibold))
            Text("The sidebar can display either standard Places or a full Directory Tree. When **Show Favorites** is enabled in options, your favorite folders appear right above the tree for quick access. Defaults dynamically adjust based on your active Navigation Shortcut Mode.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var navigationModesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Navigation Modes")
                .font(.system(size: 14, weight: .semibold))
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.accentColor)
                        Text("GNOME Mode (Default)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("• Enter: Open folder or file\n• F2: Rename item\n• Backspace: Go up to parent folder\n• Ctrl+H: Toggle hidden files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.accentColor)
                        Text("macOS Finder Mode")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("• Cmd+Down: Open folder or file\n• Enter: Rename item\n• Cmd+Up: Go up to parent folder\n• Cmd+Shift+.: Toggle hidden files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(spacing: 4) {
                shortcutRow(action: "Quick Look Preview", shortcut: "Space")
                shortcutRow(action: "Search in Directory", shortcut: "Cmd + F")
                shortcutRow(action: "New Folder", shortcut: "Cmd + Shift + N")
                shortcutRow(action: "Item Properties / Info", shortcut: "Cmd + I")
                shortcutRow(action: "Copy Selected", shortcut: "Cmd + C")
                shortcutRow(action: "Cut Selected", shortcut: "Cmd + X")
                shortcutRow(action: "Paste Files", shortcut: "Cmd + V")
                shortcutRow(action: "Move to Trash", shortcut: "Cmd + Delete")
                shortcutRow(action: "Navigate Back / Forward", shortcut: "Cmd + [  /  Cmd + ]")
                shortcutRow(action: "Parent Folder", shortcut: "Cmd + Up")
                shortcutRow(action: "Refresh Directory", shortcut: "Cmd + R")
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func shortcutRow(action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 12))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(4)
        }
    }
    
    private var footerView: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
