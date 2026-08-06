//
//  UIApplication+TopViewController.swift
//  ommadawn
//
//  El SDK de Google necesita un UIViewController sobre el que presentar su
//  navegador embebido — SwiftUI no expone uno directamente. Se usa tanto
//  desde LoginView (login) como desde AccountProfileView (vincular cuenta).
//

import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
