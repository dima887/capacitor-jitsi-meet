//
//  JitsiMeetViewController.swift
//  Plugin
//
//  Created by Calvin Ho on 1/25/19.
//

import Foundation
import UIKit
import JitsiMeetSDK
import WebKit

public class JitsiMeetViewController: UIViewController, UIGestureRecognizerDelegate {

    fileprivate var jitsiMeetView: JitsiMeetView?
    var options: JitsiMeetConferenceOptions? = nil
    weak var delegate: JitsiMeetViewControllerDelegate?
    internal var pipViewCoordinator: PiPViewCoordinator?

    var webView: WKWebView? = nil;

    public override func viewDidLoad() {
        super.viewDidLoad()
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::viewDidLoad");
        openJitsiMeet();
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::viewWillTransition");
    }

    func openJitsiMeet() {
        cleanUp()

        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::openJitsiMeet");

        // create and configure the absorbPointerView and jitsimeet view
        let jmView = JitsiMeetView()
            jmView.delegate = self
            self.jitsiMeetView = jmView
            jmView.join(options)

        // Enable jitsimeet view to be a view that can be displayed
        // on top of all the things, and let the coordinator to manage
        // the view state and interactions
    pipViewCoordinator = PiPViewCoordinator(withView: jmView)
    pipViewCoordinator?.configureAsStickyView(withParentView: view)

        // animate in
        jmView.alpha = 1
            pipViewCoordinator?.show()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::viewDidDisappear");
    }

    fileprivate func cleanUp() {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::cleanUp");
        pipViewCoordinator?.hide()
            pipViewCoordinator = nil

            jitsiMeetView?.delegate = nil
            jitsiMeetView?.removeFromSuperview()
            jitsiMeetView = nil

    }

    public func leave() {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::leave");
        (self.jitsiMeetView as? JitsiMeetView)?.hangUp()
    }
}

protocol JitsiMeetViewControllerDelegate: AnyObject {
    func onConferenceJoined()
    func onConferenceLeft()
    func onChatMessageReceived(_ dataString: String)
    func onParticipantsInfoRetrieved(_ dataString: String)
    func onCustomButtonPressed(_ dataString: String)
}

// MARK: JitsiMeetViewDelegate
extension JitsiMeetViewController: JitsiMeetViewDelegate {

    @objc public func conferenceJoined(_ data: NSDictionary) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::conference joined");
        delegate?.onConferenceJoined()
        if let jmView = self.jitsiMeetView as? JitsiMeetView {
            jmView.retrieveParticipantsInfo { data in
                if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
                   let text = String(data: json, encoding: .ascii) {
                    self.delegate?.onParticipantsInfoRetrieved(text)
                }
            }
        }
    }

    @objc public func ready(toClose: [AnyHashable : Any]!) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::ready to close");
        delegate?.onConferenceLeft()
    }

    @objc public func conferenceTerminated(_ data: NSDictionary) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::conference terminated");
        delegate?.onConferenceLeft()
    }

    @objc public func chatMessageReceived(_ data: NSDictionary) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::chat message received");
        if let theJSONData = try?  JSONSerialization.data(
              withJSONObject: data,
              options: .prettyPrinted
              ),
              let theJSONText = String(data: theJSONData,
                                   encoding: String.Encoding.ascii) {
              print("JSON string = \n\(theJSONText)")
            delegate?.onChatMessageReceived(theJSONText)
        }
    }

    @objc public func customOverflowMenuButtonPressed(_ data: NSDictionary) {
        print("[Jitsi Plugin Native iOS]: Custom button pressed")

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            delegate?.onCustomButtonPressed(jsonString)
        }
    }


}