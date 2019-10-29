// SPDX-License-Identifier: MPL-2.0
// Copyright © 2019 Mozilla Corporation. All Rights Reserved.

import UIKit
import SafariServices

class LoginViewController: UIViewController {
    private let successfulLoginString = "/vpn/client/login/success"
    private let accountManager: AccountManaging
    private weak var navigatingDelegate: Navigating?

    private var safariViewController: SFSafariViewController?
    private var verificationUrl: URL?
    private var verifyTimer: Timer?
    private var isVerifying = false

    init(accountManager: AccountManaging, navigatingDelegate: Navigating) {
        self.accountManager = accountManager
        self.navigatingDelegate = navigatingDelegate
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        verifyTimer?.invalidate()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        accountManager.login { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let checkPointModel):
                DispatchQueue.main.async {
                    self.verificationUrl = checkPointModel.verificationUrl
                    let safariVc = SFSafariViewController(url: checkPointModel.loginUrl)
                    self.addChild(safariVc)
                    self.view.addSubview(safariVc.view)
                    safariVc.view.frame = self.view.bounds
                    safariVc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    safariVc.didMove(toParent: self)
                    safariVc.delegate = self
                    self.safariViewController = safariVc
                }
            case .failure:
                // TODO: Handle failure here
                print("Failure: Could not retrieve login page")
            }
        }
    }

    @objc private func verify() {
        guard let verificationUrl = verificationUrl else { return }
        if isVerifying { return }
        isVerifying = true
        accountManager.setupFromVerify(url: verificationUrl) { [unowned self] result in
            self.isVerifying = false
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.verifyTimer?.invalidate()
                    self.accountManager.finishSetupFromVerify { finishResult in
                        DispatchQueue.main.async {
                            switch finishResult {
                            case .failure(let error):
                                // TODO: Remove print statement
                                print(error)
                                self.navigatingDelegate?.navigate.onNext(.loginFailed)
                            case .success:
                                self.navigatingDelegate?.navigate.onNext(.loginSucceeded)
                            }
                        }
                    }
                case .failure(let error):
                    // TODO: Remove print statement
                    print(error)
                    print("Failure: Could not verify")
                }
            }
        }
    }
}

// MARK: - SFSafariViewControllerDelegate
extension LoginViewController: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
        if didLoadSuccessfully && verifyTimer == nil {
            verifyTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(verify), userInfo: nil, repeats: true)
        }
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        // TODO: This should animate smoothly
        self.navigatingDelegate?.navigate.onNext(.loading)
    }
}