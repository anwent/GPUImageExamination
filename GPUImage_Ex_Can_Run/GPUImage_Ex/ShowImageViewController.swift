//
//  ShowImageViewController.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/17.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit

class ShowImageViewController: UIViewController {

    public var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView(frame: UIScreen.main.bounds)
        imageView.backgroundColor = .clear
        return imageView
    }()
    
    override func loadView() {
        super.loadView()
        
        view.backgroundColor = .red
        
        view.addSubview(imageView)
    }
    

}
