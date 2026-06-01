import Cocoa
import UniformTypeIdentifiers
import WebKit

final class SaveMessageHandler: NSObject, WKScriptMessageHandler {
    weak var window: NSWindow?

    init(window: NSWindow? = nil) {
        self.window = window
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let html = body["html"] as? String
        else {
            return
        }

        let filename = (body["filename"] as? String)?.isEmpty == false
            ? body["filename"] as! String
            : "edited_presentation.html"

        DispatchQueue.main.async { [weak self] in
            let panel = NSSavePanel()
            panel.title = "导出 HTML"
            panel.nameFieldStringValue = filename
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.html]

            let completion: (NSApplication.ModalResponse) -> Void = { response in
                guard response == .OK, let url = panel.url else {
                    return
                }
                do {
                    try html.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "导出失败"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    if let window = self?.window {
                        alert.beginSheetModal(for: window)
                    } else {
                        alert.runModal()
                    }
                }
            }

            if let window = self?.window {
                panel.beginSheetModal(for: window, completionHandler: completion)
            } else {
                completion(panel.runModal())
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var saveHandler: SaveMessageHandler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        buildWindow()
        loadEditor()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "关于 HTML报告编辑器", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "隐藏 HTML报告编辑器", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出 HTML报告编辑器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenuItem.submenu = fileMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let contentController = WKUserContentController()
        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "HTML报告编辑器"
        window.minSize = NSSize(width: 980, height: 680)
        window.center()
        window.delegate = self
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        saveHandler = SaveMessageHandler(window: window)
        contentController.add(saveHandler, name: "htmlReportLiveEditorSave")
    }

    private func loadEditor() {
        let bundleURL = Bundle.main.bundleURL
        let workspaceURL = bundleURL.deletingLastPathComponent()
        let bundledHTMLURL = Bundle.main.url(forResource: "html-report-live-editor", withExtension: "html")
        let siblingHTMLURL = workspaceURL.appendingPathComponent("html-report-live-editor.html")
        let htmlURL = bundledHTMLURL ?? siblingHTMLURL
        let readAccessURL = bundledHTMLURL?.deletingLastPathComponent() ?? workspaceURL

        guard FileManager.default.fileExists(atPath: htmlURL.path) else {
            let alert = NSAlert()
            alert.messageText = "找不到 html-report-live-editor.html"
            alert.informativeText = "App 资源不完整。请重新生成 HTML报告编辑器.app。"
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: readAccessURL)
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = "选择文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canCreateDirectories = false

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else {
                completionHandler(nil)
                return
            }
            completionHandler(panel.urls)
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
