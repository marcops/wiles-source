import Foundation
import AppKit

@MainActor
public class AutoOrganizationService {
    public static let shared = AutoOrganizationService()
    
    private let rulesKey = "wiles_autoOrganizationRules"
    
    public var rules: [AutoOrganizationRule] = [] {
        didSet {
            saveRules()
            restartMonitoring()
        }
    }
    
    private var fileMonitors: [String: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [String: CInt] = [:]
    
    private init() {
        loadRules()
    }
    
    public func startMonitoring() {
        restartMonitoring()
    }
    
    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let loaded = try? JSONDecoder().decode([AutoOrganizationRule].self, from: data) {
            self.rules = loaded
        }
    }
    
    private func saveRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }
    
    public func addRule(_ rule: AutoOrganizationRule) {
        rules.append(rule)
    }
    
    public func updateRule(_ rule: AutoOrganizationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }
    
    public func deleteRule(id: UUID) {
        rules.removeAll(where: { $0.id == id })
    }
    
    private func restartMonitoring() {
        // Stop existing
        for (_, source) in fileMonitors {
            source.cancel()
        }
        for (_, fd) in fileDescriptors {
            close(fd)
        }
        fileMonitors.removeAll()
        fileDescriptors.removeAll()
        
        let activeRules = rules.filter { $0.isEnabled }
        let uniqueSourceFolders = Set(activeRules.map { $0.sourceURL.standardizedFileURL })
        
        for folder in uniqueSourceFolders {
            startWatching(folder: folder)
        }
    }
    
    private func startWatching(folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        
        source.setEventHandler { [weak self] in
            self?.processFolder(folder)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        fileDescriptors[folder.path] = fd
        fileMonitors[folder.path] = source
        source.resume()
    }
    
    private func processFolder(_ folder: URL) {
        let activeRules = rules.filter { $0.isEnabled && $0.sourceURL.standardizedFileURL == folder.standardizedFileURL }
        guard !activeRules.isEmpty else { return }
        
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) else {
            return
        }
        
        for file in files {
            // Ignore hidden files and directories
            if file.lastPathComponent.hasPrefix(".") { continue }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: file.path, isDirectory: &isDir), isDir.boolValue {
                continue
            }
            
            for rule in activeRules {
                if matches(file: file, rule: rule) {
                    // Move file natively using UndoRedoService for safe undo
                    Task {
                        do {
                            _ = try FileSystemService.moveItem(at: file, toFolder: rule.destinationURL)
                            UndoRedoService.shared.recordAction(.move(sourceURL: file, destinationURL: rule.destinationURL.appendingPathComponent(file.lastPathComponent)))
                            print("Auto-Organized: \(file.lastPathComponent) to \(rule.destinationURL.path)")
                        } catch {
                            print("Failed to auto-organize \(file.path): \(error)")
                        }
                    }
                    break // Stop checking other rules for this file if one matched
                }
            }
        }
    }
    
    private func matches(file: URL, rule: AutoOrganizationRule) -> Bool {
        let name = file.lastPathComponent
        let ext = file.pathExtension
        
        switch rule.conditionType {
        case .extensionEquals:
            return ext.caseInsensitiveCompare(rule.conditionValue) == .orderedSame
        case .nameContains:
            return name.localizedCaseInsensitiveContains(rule.conditionValue)
        case .namePrefix:
            return name.lowercased().hasPrefix(rule.conditionValue.lowercased())
        }
    }
}
