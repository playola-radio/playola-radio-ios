//
//  ShareSheet.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/21/25.
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: Context
    ) {}
}
