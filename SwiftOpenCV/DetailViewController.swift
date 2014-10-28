//
//  DetailViewController.swift
//
//  Created by Lee Whitney on 10/28/14.
//  Copyright (c) 2014 WhitneyLand. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    var recognizedText: String!
    
    @IBOutlet weak var recTextView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        recTextView.text = recognizedText;
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
