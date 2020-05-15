//
//  StartNavigationControllerViewController.swift
//  template-cells
//
//  Created by Dimitrios Brukakis on 12.05.20.
//  Copyright © 2020 Cellular. All rights reserved.
//

import UIKit

class StartNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changeRootViewController(identifier: "StartViewController")
    }
    
    func changeRootViewController(identifier: String) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: identifier) {
            viewControllers = [viewController]
        }
    }
}
