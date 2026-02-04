//
//  ApoRightMenuApp.swift
//  ApoRightMenu
//
//  Created by 阿坡 on 2026/02/03.
//

import SwiftUI

@main
struct ApoRightMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
