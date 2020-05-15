//
//  ViewController.swift
//  template-cells
//
//  Created by Dimitrios Brukakis on 11.05.20.
//  Copyright © 2020 Cellular. All rights reserved.
//

import UIKit

class StartViewController: UIViewController {
    
    
    @IBOutlet private weak var rightImageView: UIImageView?
    @IBOutlet private weak var midImageView: UIImageView?
    @IBOutlet private weak var leftImageView: UIImageView?
    
    override func viewDidLoad() {
        navigationController?.navigationBar.isHidden = true
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveEaseIn], animations: {
            self.rightImageView?.center.x = self.view.frame.width + 100
            self.leftImageView?.center.x = -100
            self.midImageView?.alpha = 0.0
        }) { (completed) in
            guard let navigationController = self.navigationController as? StartNavigationController else { return }
            navigationController.changeRootViewController(identifier: "MainTabController")
        }
    }

}

