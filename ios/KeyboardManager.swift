//
//  KeyboardManager.swift
//  KeyboardDemo
//
//  Created by Mind-0002 on 21/04/17.
//  Copyright © 2017 Mind. All rights reserved.
//

import Foundation
import UIKit

protocol keyboardManagerDelegate :class {
    func keyboardWillShow(notification:Notification , keyboardHeight:CGFloat)
    func keyboardDidHide(notification:Notification)
}

class KeyboardManager  {
    
    private init() {}
    
    private static var keyboardmanager:KeyboardManager = {
        let keyboardmanager = KeyboardManager()
        return keyboardmanager
    }()
    
    static func shared() ->  KeyboardManager  {
        return keyboardmanager
    }
    
    weak var delegate:keyboardManagerDelegate?
    
    @objc  private func keyboardWillShow(notification:Notification) {
        
        let info = notification.userInfo
      let keyboardHeight = (info?[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.height
        
        delegate?.keyboardWillShow(notification: notification, keyboardHeight: keyboardHeight)
    }
    
    @objc private func keyboardDidHide(notification:Notification) {
        delegate?.keyboardDidHide(notification: notification)
    }
    
}

