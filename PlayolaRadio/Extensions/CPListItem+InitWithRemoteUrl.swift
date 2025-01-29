//
//  CPListItem+InitWithRemoteUrl.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/20/25.
//
import CarPlay

extension CPListItem {
    private static let identifierUserInfoKey = "CPListItem.Identifier"

    public convenience init(
        text: String?,
        detailText: String?,
        remoteImageUrl: URL?,
        placeholder: UIImage?
    ) {
        self.init(text: text, detailText: detailText, image: placeholder)

        if let remoteImageUrl {
            let dataTask = URLSession.shared.dataTask(with: remoteImageUrl) { [weak self] data, _, _ in
                if let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async { [weak self] in
                        self?.setImage(image)
                    }
                } else {
                    print("Error downlaoding image")
                }
            }
            dataTask.resume()
        }

        var identifier: String? {
            (userInfo as? [String: Any])?[Self.identifierUserInfoKey] as? String
        }
    }
}
