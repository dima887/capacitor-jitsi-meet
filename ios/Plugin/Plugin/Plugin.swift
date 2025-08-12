import Foundation
import Capacitor
import JitsiMeetSDK
import UIKit
/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(Jitsi)
public class Jitsi: CAPPlugin {

    var jitsiMeetViewController: JitsiMeetViewController?

    @objc func joinConference(_ call: CAPPluginCall) {

        let podBundle = Bundle(for: JitsiMeetViewController.self)
        let bundleURL = podBundle.url(forResource: "Plugin", withExtension: "bundle")
        let bundle = Bundle(url: bundleURL!)!

        let storyboard = UIStoryboard(name: "JitsiMeet", bundle: bundle)
        self.jitsiMeetViewController = storyboard.instantiateViewController(withIdentifier: "jitsiMeetStoryBoardID") as? JitsiMeetViewController
        guard let url = call.options["url"] as? String else {
            call.reject("Must provide an url")
            return
        }
        guard let roomName = call.options["roomName"] as? String else {
            call.reject("Must provide a roomName")
            return
        }
        let subject = call.options["subject"] as? String ?? " "

        self.jitsiMeetViewController?.webView = self.webView

        self.jitsiMeetViewController?.options = JitsiMeetConferenceOptions.fromBuilder { (builder) in
            builder.serverURL = URL(string: url)
            builder.room = roomName
            builder.setSubject(subject)
            builder.setFeatureFlag("ios.screensharing.enabled", withBoolean: true)

            if let token = call.options["token"] as? String {
                builder.token = token;
            }

            if let isAudioMuted = call.options["startWithAudioMuted"] as? Bool {
                builder.setAudioMuted(isAudioMuted);
            }

            /* if let isAudioOnly = call.options["isAudioOnly"] as? Bool {
                builder.setAudioOnly(isAudioOnly)
            } */

            if let isVideoMuted = call.options["startWithVideoMuted"] as? Bool {
                builder.setVideoMuted(isVideoMuted)
            }

            let displayName = call.options["displayName"] as? String
            let email = call.options["email"] as? String
            let avatarUrlString = call.options["avatarURL"] as? String

            if (displayName != nil || email != nil || avatarUrlString != nil) {
                let avatarUrl = avatarUrlString != nil ? URL(string: avatarUrlString!) : nil
                builder.userInfo = JitsiMeetUserInfo(displayName: displayName, andEmail: email, andAvatar: avatarUrl)
            }

            // default PiP is off as the feature is not fully functioning yet, but allow user to overrides it by providing the featureFlag
            builder.setFeatureFlag("pip.enabled", withBoolean: false)

            // if not set in the feature flags above, this will take effect
            if let chatEnabled = call.options["chatEnabled"] as? Bool {
                builder.setFeatureFlag("chat.enabled", withBoolean: chatEnabled)
            }
            if let inviteEnabled = call.options["inviteEnabled"] as? Bool {
                builder.setFeatureFlag("invite.enabled", withBoolean: inviteEnabled)
            }

            // setfeatureFlag() provides finer control, and will override some of the settings above
            let featureFlags = call.options["featureFlags"] as? Dictionary<String, Any>

            featureFlags?.forEach { key, value in
                var readValue = value
                if (key == "call-integration.enabled") {
                    let userLocale = NSLocale.current as NSLocale
                    if  userLocale.countryCode?.contains("CN") ?? false ||
                        userLocale.countryCode?.contains("CHN") ?? false ||
                        userLocale.countryCode?.contains("MO") ?? false ||
                        userLocale.countryCode?.contains("HK") ?? false {
                        print("currentLocale is China so we cannot use CallKit.")
                        readValue = false
                    }
                }
                builder.setFeatureFlag(key, withValue: readValue);
            }
            #if DEBUG
                builder.setFeatureFlag("call-integration.enabled", withValue: false);
                print("disable CallKit in debug mode to prevent call from disconnecting in simulators.")
            #endif

            let configOverrides = call.options["configOverrides"] as? Dictionary<String, Any>
            configOverrides?.forEach { key, value in
                builder.setConfigOverride(key, withValue: value);
            }
        }

        self.jitsiMeetViewController?.delegate = self;

        DispatchQueue.main.async {
            // New join conference
            if let parentVC = self.bridge?.viewController,
               let jitsiVC = self.jitsiMeetViewController {

                parentVC.addChild(jitsiVC)
                parentVC.view.addSubview(jitsiVC.view)
                jitsiVC.view.frame = parentVC.view.bounds
                jitsiVC.didMove(toParent: parentVC)

                call.resolve(["success": true])
            }
        }
    }

    @objc func leaveConference(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            // 1. Jitsi SDK: отправить "hangUp"/"leave"
            self.jitsiMeetViewController?.leave()

            // 2. Удаляем из родителя
            if let jitsiVC = self.jitsiMeetViewController {
                jitsiVC.willMove(toParent: nil)
                jitsiVC.view.removeFromSuperview()
                jitsiVC.removeFromParent()
            }

            // 3. Обнулить ссылку
            self.jitsiMeetViewController = nil

            // 4. Возвращаемся
            call.resolve(["success": true])
        }
    }

    @objc func enterPictureInPictureMode(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.jitsiMeetViewController?.pipViewCoordinator?.enterPictureInPicture()
            call.resolve(["success": true])
        }
    }

    @objc func hideConference(_ call: CAPPluginCall) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::hideConference");
        DispatchQueue.main.async {
            self.jitsiMeetViewController?.view.isHidden = true
            call.resolve(["success": true])
        }
    }

    @objc func showConference(_ call: CAPPluginCall) {
        print("[Jitsi Plugin Native iOS]: JitsiMeetViewController::showConference");
        DispatchQueue.main.async {
            self.jitsiMeetViewController?.view.isHidden = false
            call.resolve(["success": true])
        }
    }
}

extension Jitsi: JitsiMeetViewControllerDelegate {
    @objc func onConferenceJoined() {
        self.bridge?.triggerWindowJSEvent(eventName: "onConferenceJoined");
    }

    @objc func onConferenceLeft() {
        self.bridge?.triggerWindowJSEvent(eventName: "onConferenceLeft");
    }

    @objc func onChatMessageReceived(_ dataString: String) {
        self.bridge?.triggerWindowJSEvent(eventName: "onChatMessageReceived", data: dataString);
    }

    @objc func onParticipantsInfoRetrieved(_ dataString: String) {
        self.bridge?.triggerWindowJSEvent(eventName: "onParticipantsInfoRetrieved", data: dataString);
    }

    @objc func onCustomButtonPressed(_ dataString: String) {
        self.bridge?.triggerWindowJSEvent(eventName: "onCustomButtonPressed", data: dataString)
    }
}
