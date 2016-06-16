//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

import Firebase

@objc(SignInViewController)
class SignInViewController: UIViewController {

  @IBOutlet weak var emailField: UITextField!
  @IBOutlet weak var passwordField: UITextField!

  override func viewDidAppear(animated: Bool) {
    if let user = FIRAuth.auth()?.currentUser {
        self.signedIn(user)
    }
  }

  @IBAction func didTapSignIn(sender: AnyObject) {
    guard let email = emailField.text, password = passwordField.text else {
        return
    }
    
    FIRAuth.auth()?.signInWithEmail(email, password: password, completion: { (user, error) in
        if let error = error {
            print(error.localizedDescription)
            return
        }
        self.signedIn(user)
    })
  }

  @IBAction func didTapSignUp(sender: AnyObject) {
    guard let email = emailField.text, password = passwordField.text else {
        return
    }
    
    FIRAuth.auth()?.createUserWithEmail(email, password: password, completion: { (user, error) in
        if let error = error {
            print(error.localizedDescription)
            return
        }
        self.setDisplayName(user)
    })
  }

  func setDisplayName(user: FIRUser?) {
    guard let user = user, email = user.email else {
        return
    }
    
    let changeRequest = user.profileChangeRequest()
    changeRequest.displayName = email.componentsSeparatedByString("@")[0]
    changeRequest.commitChangesWithCompletion { (error) in
        if let error = error {
            print(error.localizedDescription)
            return
        }
        self.signedIn(FIRAuth.auth()?.currentUser)
    }
  }

  @IBAction func didRequestPasswordReset(sender: AnyObject) {
    let alert = UIAlertController.init(title: nil, message: "Email:", preferredStyle: .Alert)
    let okAction = UIAlertAction.init(title: "ok", style: .Default) { (action) in
        
        guard let userInput = alert.textFields![0].text where !userInput.isEmpty else {
            return
        }
        FIRAuth.auth()?.sendPasswordResetWithEmail(userInput, completion: { (error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
        })
    }
    alert.addTextFieldWithConfigurationHandler(nil)
    alert.addAction(okAction)
    presentViewController(alert, animated: true, completion: nil)
  }

  func signedIn(user: FIRUser?) {
    guard let user = user else {
        return
    }
    
    MeasurementHelper.sendLoginEvent()

    AppState.sharedInstance.signedIn = true
    AppState.sharedInstance.displayName = user.displayName
    AppState.sharedInstance.photoUrl = user.photoURL
    NSNotificationCenter.defaultCenter().postNotificationName(Constants.NotificationKeys.SignedIn, object: nil, userInfo: nil)
    performSegueWithIdentifier(Constants.Segues.SignInToFp, sender: nil)
  }

    @IBAction func done(segue: UIStoryboardSegue) {
    }
    
}
