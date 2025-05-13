// AppDelegate.swift
import UIKit
import SwiftUI // Keep if you still use UIHostingController here, but not needed if MosaicApp.swift is @main

// REMOVE @main from here if MosaicApp.swift is now your @main entry point
// @main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // This setup is only needed if AppDelegate is still @main.
        // If MosaicApp.swift is @main, this code can be removed.
        print("AppDelegate: didFinishLaunchingWithOptions")

        // If you switch to MosaicApp.swift as @main, you typically remove this window setup.
        // SwiftUI's App lifecycle handles window creation.
        /*
        let contentView = ContentView()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        */
        return true
    }

    // ... other AppDelegate methods if you have them ...
}
