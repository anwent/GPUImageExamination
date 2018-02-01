//
//  DrawViewController.swift
//  GPUImage_Ex
//
//  Created by wow250250 on 2018/1/17.
//  Copyright © 2018年 wow250250. All rights reserved.
//

import UIKit

extension UIView {
    public func `addSubview`(view: UIView?) {
        guard let v = view else {
            assert(true, "view is NULL")
            return
        }
        addSubview(v)
    }
}

class DrawViewController: UIViewController {

    var draw: DrawView?
    var drawCtl: FreehandDraw?

    private lazy var undoItem: UIBarButtonItem = {
        let c = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        c.setTitle("Undo", for: .normal)
        c.setTitleColor(.gray, for: .normal)
        c.addTarget(self, action: #selector(self.undoTarget), for: .touchUpInside)
        let bar = UIBarButtonItem(customView: c)
        return bar
    }()

    private lazy var nextItem: UIBarButtonItem = {
        let c = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        c.setTitle("Next", for: .normal)
        c.setTitleColor(.gray, for: .normal)
        c.addTarget(self, action: #selector(self.nextTarget), for: .touchUpInside)
        let bar = UIBarButtonItem(customView: c)
        return bar
    }()

    var emojiLabel: EditLabel?
    
    public var moviePath: URL {
//        return Bundle.main.url(forResource: "x", withExtension: "mov")!
//        return Bundle.main.url(forResource: "abc", withExtension: "mp4")!
        return Bundle.main.url(forResource: "h", withExtension: "mp4")!
    }

    override func loadView() {
        super.loadView()

        title = "Please Write"
        view.backgroundColor = .gray
        navigationItem.leftBarButtonItem = undoItem
        navigationItem.rightBarButtonItem = nextItem

        draw = DrawView(frame: UIScreen.main.bounds)
        draw?.backgroundColor = .clear

        drawCtl = FreehandDraw(canvas: draw, to: view)
        view.addSubview(view: draw)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        emojiLabel = EditLabel(content: "😄")
        view.addSubview(view: emojiLabel)
        
        
        let rrr = THImageMovieWriter.degressFromVideoFile(with: moviePath)
        print("R: --- ", rrr)

    }

    @objc func undoTarget() {
        drawCtl?.revoked()
    }

    @objc func nextTarget() {

        let vc = ViewController()

        var wm = Watermark()
        wm.draw = [Watermark_Draw(buffer: draw?.buffer)]
        wm.emoji = [Watermark_Emoji(buffer: emojiLabel)]

        vc.watermark = wm
        navigationController?.show(vc, sender: true)
    }
}
