//
//  Main.swift
//  Apple SuCheng
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

@main
struct AppleSuChengApp {
  static let userDir = if let pwuid = getpwuid(getuid()) {
    URL(fileURLWithFileSystemRepresentation: pwuid.pointee.pw_dir, isDirectory: true, relativeTo: nil).appending(components: "Library", "AppleSuCheng")
  } else {
    try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("AppleSuCheng", isDirectory: true)
  }
  // 勿寫死路徑：同路徑若曾用舊 Bundle ID 註冊，TIS 會黏住舊 bundle 導致無法啟用
  static var appDir: URL { Bundle.main.bundleURL }
  static let logDir = FileManager.default.temporaryDirectory.appending(component: "rime.applesucheng", directoryHint: .isDirectory)

  // swiftlint:disable:next cyclomatic_complexity
  static func main() {
    let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee

    let handled = autoreleasepool {
      let installer = AppleSuChengInstaller()
      let args = CommandLine.arguments
      if args.count > 1 {
        switch args[1] {
        case "--quit":
          let bundleId = Bundle.main.bundleIdentifier!
          let runningAppleSuCheng = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
          runningAppleSuCheng.forEach { $0.terminate() }
          return true
        case "--reload":
          // Background IM apps: AppKit suspends distributed-notification delivery when inactive;
          // deliverImmediately is required so notifications reach Apple SuCheng in the background
          DistributedNotificationCenter.default().postNotificationName(.init("AppleSuChengReloadNotification"), object: nil, userInfo: nil, deliverImmediately: true)
          return true
        case "--register-input-source", "--install":
          installer.register()
          return true
        case "--enable-input-source":
          if args.count > 2 {
            let modes = args[2...].map { AppleSuChengInstaller.InputMode(rawValue: $0) }.compactMap { $0 }
            if !modes.isEmpty {
              installer.enable(modes: modes)
              return true
            }
          }
          installer.enable()
          return true
        case "--disable-input-source":
          if args.count > 2 {
            let modes = args[2...].map { AppleSuChengInstaller.InputMode(rawValue: $0) }.compactMap { $0 }
            if !modes.isEmpty {
              installer.disable(modes: modes)
              return true
            }
          }
          installer.disable()
          return true
        case "--select-input-source":
          if args.count > 2, let mode = AppleSuChengInstaller.InputMode(rawValue: args[2]) {
            installer.select(mode: mode)
          } else {
            installer.select()
          }
          return true
        case "--build":
          AppleSuChengApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_update", comment: ""))
          var builderTraits = RimeTraits.rimeStructInit()
          builderTraits.setCString("rime.applesucheng-builder", to: \.app_name)
          rimeAPI.setup(&builderTraits)
          rimeAPI.deployer_initialize(nil)
          _ = rimeAPI.deploy()
          return true
        case "--sync":
          DistributedNotificationCenter.default().postNotificationName(.init("AppleSuChengSyncNotification"), object: nil, userInfo: nil, deliverImmediately: true)
          return true
        case "--ascii":
          DistributedNotificationCenter.default().postNotificationName(.init("AppleSuChengToggleASCIIModeNotification"), object: "ascii", userInfo: nil, deliverImmediately: true)
          return true
        case "--nascii":
          DistributedNotificationCenter.default().postNotificationName(.init("AppleSuChengToggleASCIIModeNotification"), object: "nascii", userInfo: nil, deliverImmediately: true)
          return true
        case "--getascii":
          var responseReceived = false
          var asciiStatus = ""
          let observer = DistributedNotificationCenter.default().addObserver(
            forName: .init("AppleSuChengASCIIModeResponse"),
            object: nil,
            queue: .main
          ) { notification in
            if let status = notification.object as? String {
              asciiStatus = status
              responseReceived = true
            }
          }
          DistributedNotificationCenter.default().postNotificationName(.init("AppleSuChengGetASCIIModeNotification"), object: nil, userInfo: nil, deliverImmediately: true)
          let timeout = Date().addingTimeInterval(2.0)
          while !responseReceived && Date() < timeout {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
          }
          DistributedNotificationCenter.default().removeObserver(observer)
          if responseReceived {
            print(asciiStatus)
          } else {
            print("nascii")
          }
          return true
        case "--help":
          print(helpDoc)
          return true
        default:
          break
        }
      }
      return false
    }
    if handled {
      return
    }

    autoreleasepool {
      let main = Bundle.main
      let connectionName = main.object(forInfoDictionaryKey: "InputMethodConnectionName") as! String
      _ = IMKServer(name: connectionName, bundleIdentifier: main.bundleIdentifier!)
      let app = NSApplication.shared
      let delegate = AppleSuChengApplicationDelegate()
      app.delegate = delegate
      app.setActivationPolicy(.accessory)

      // OpenCC uses relative dictionary paths from SharedSupport.
      FileManager.default.changeCurrentDirectoryPath(main.sharedSupportPath!)

      if NSApp.appleSuChengAppDelegate.problematicLaunchDetected() {
        print("Problematic launch detected!")
        let args = ["Problematic launch detected! Apple SuCheng may be suffering a crash due to improper configuration. Revert previous modifications to see if the problem recurs."]
        let task = Process()
        task.executableURL = "/usr/bin/say".withCString { dir in
          URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
        }
        task.arguments = args
        try? task.run()
      } else {
        NSApp.appleSuChengAppDelegate.setupRime()
        NSApp.appleSuChengAppDelegate.startRime(fullCheck: false)
        NSApp.appleSuChengAppDelegate.loadSettings()
        print("Apple SuCheng reporting!")
      }

      app.run()
      print("Apple SuCheng is quitting...")
      rimeAPI.finalize()
    }
    return
  }

  static let helpDoc = """
Supported arguments:
Perform actions:
  --quit                     quit all Apple SuCheng processes
  --reload                   deploy
  --sync                     sync user data
  --build                    build all schemas in current directory
  --ascii                    turn on ASCII mode
  --nascii                   turn off ASCII mode
  --getascii                 get current ASCII mode status
Install Apple SuCheng:
  --install, --register-input-source    register input source
  --enable-input-source [source id...]  input source list optional
  --disable-input-source [source id...] input source list optional
  --select-input-source [source id]     input source optional
"""
}
