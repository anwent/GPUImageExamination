//
//  EditLabel.swift
//  EmojiKeyboard
//
//  Created by wow250250 on 2017/7/11.
//  Copyright © 2017年 ZZH. All rights reserved.
//

import UIKit

protocol EmojiEditDelegate: class {
    func editLabel(_ editLabel: EditLabel, touchesMoved center: CGPoint)
    func editLabel(_ editLabel: EditLabel, touchEnded center: CGPoint)
    func editLabel(_ editLabel: EditLabel, touchesBegan center: CGPoint)
}

class EditLabel: UILabel {
    
    private static let emojiSize: CGSize = CGSize(width: 50, height: 50)
    private static let editLabelX: CGFloat = 100.0
    private static let editLabelY: CGFloat = 100.0
    
    weak var emojiEditDelegate: EmojiEditDelegate?
    
    init(content: String?) {
        super.init(frame: CGRect(origin: CGPoint(x: EditLabel.editLabelX, y: EditLabel.editLabelY),
                                 size: EditLabel.emojiSize))
        textAlignment = .center
        text = content
        isUserInteractionEnabled = true
        font = UIFont.systemFont(ofSize: 40)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        emojiEditDelegate?.editLabel(self, touchesBegan: center)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        print("Emoji Touches Moved")
        
        guard let touch = touches.first else { return }
        let nowLocation = touch.location(in: self)
        let preLocation = touch.previousLocation(in: self)
        let offsetX = nowLocation.x - preLocation.x
        let offsetY = nowLocation.y - preLocation.y
        var center = self.center
        center.x += offsetX
        center.y += offsetY
        self.center = center
        emojiEditDelegate?.editLabel(self, touchesMoved: center)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        emojiEditDelegate?.editLabel(self, touchEnded: center)
        print("Emoji Touches Ended")
    }
}
