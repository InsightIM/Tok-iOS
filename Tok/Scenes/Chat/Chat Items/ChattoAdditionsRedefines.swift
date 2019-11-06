//
//  ChattoAdditionsRedefines.swift
//  Tok
//
//  Created by Bryce on 2019/5/20.
//  Copyright © 2019 Insight. All rights reserved.
//

import Chatto
import ChattoAdditions
import Reusable
import RxSwift
import RxCocoa

public typealias ChattoAdditionsMessageModel = ChattoAdditions.MessageModel
public typealias ChattoAdditionsTextMessageModel = ChattoAdditions.TextMessageModel<ChattoAdditionsMessageModel>
public typealias ChattoAdditionsTextMessageViewModel = ChattoAdditions.TextMessageViewModel

public typealias ChattoAdditionsMessageStatus = ChattoAdditions.MessageStatus

public typealias ChattoAdditionsPhotoMessageModel = ChattoAdditions.PhotoMessageModel<ChattoAdditionsMessageModel>
public typealias ChattoAdditionsPhotoMessageViewModel = ChattoAdditions.PhotoMessageViewModel

extension UICollectionViewCell: Reusable {}

protocol RenewableType {
    var renewable: Bool { get }
}

protocol TransferProgressHanlder: RenewableType {
    var disposeBag: DisposeBag { get }
    var transferStatus: TransferStatus { get }
    var progress: BehaviorRelay<Double> { get }
}

protocol FileOperationHandlerProtocol {
    associatedtype ViewModelT
    func userDidTapOnOperationButton(viewModel: ViewModelT)
}

extension TextMessageModel {
    static var chatItemType: ChatItemType {
        return "text"
    }
}

extension PhotoMessageModel {
    static var chatItemType: ChatItemType {
        return "photo"
    }
}

extension AudioMessageModel {
    static var chatItemType: ChatItemType {
        return "audio"
    }
}

extension FileMessageModel {
    static var chatItemType: ChatItemType {
        return "file"
    }
}

extension VideoMessageModel {
    static var chatItemType: ChatItemType {
        return "video"
    }
}
