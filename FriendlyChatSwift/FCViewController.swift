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

import Photos
import UIKit

import Firebase
import GoogleMobileAds

/**
 * AdMob ad unit IDs are not currently stored inside the google-services.plist file. Developers
 * using AdMob can store them as custom values in another plist, or simply use constants. Note that
 * these ad units are configured to return only test ads, and should not be used outside this sample.
 */
let kBannerAdUnitID = "###################"

@objc(FCViewController)
class FCViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

  // Instance variables
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var sendButton: UIButton!
    
  var ref: FIRDatabaseReference!
  var messages: [FIRDataSnapshot]! = []
  var msglength: NSNumber = 10
  private var _refHandle: FIRDatabaseHandle!

  var storageRef: FIRStorageReference!
  var remoteConfig: FIRRemoteConfig!

  @IBOutlet weak var banner: GADBannerView!
  @IBOutlet weak var clientTable: UITableView!


  override func viewDidLoad() {
    super.viewDidLoad()

    ref = FIRDatabase.database().reference()
    self.clientTable.registerClass(UITableViewCell.self, forCellReuseIdentifier: "tableViewCell")
    loadAd()
    fetchConfig()
    configureStorage()
    
    FIRCrashMessage("View loaded")
//    FirebaseCrash.log("SQL database failed to initialize");
  }

    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.messages.removeAll()
        _refHandle = self.ref.child("messages").observeEventType(.ChildAdded, withBlock: { (snapshot) in
            self.messages.append(snapshot)
            self.clientTable.insertRowsAtIndexPaths([NSIndexPath(forRow: self.messages.count-1, inSection: 0)], withRowAnimation: .Automatic)
        })
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.ref.removeObserverWithHandle(_refHandle)
        super.viewWillDisappear(animated)
    }
    
    
  func configureDatabase() {
  }

  func configureStorage() {
    storageRef = FIRStorage.storage().referenceForURL("###########################")
  }

  func configureRemoteConfig() {
  }

  func fetchConfig() {
  }

  @IBAction func didPressFreshConfig(sender: AnyObject) {
    fetchConfig()
  }

  @IBAction func didSendMessage(sender: UIButton) {
    textFieldShouldReturn(textField)
  }

  @IBAction func didPressCrash(sender: AnyObject) {
    FIRCrashMessage("Cause Crash button clicked")
    fatalError()
  }

  func logViewLoaded() {
  }


    func loadAd() {
        self.banner.adUnitID = kBannerAdUnitID
        self.banner.rootViewController = self
        self.banner.loadRequest(GADRequest())
    }


  func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
    guard let text = textField.text else { return true }

    let newLength = text.utf16.count + string.utf16.count - range.length
    return newLength <= self.msglength.integerValue // Bool
  }

  // UITableViewDataSource protocol methods
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return messages.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    // Dequeue cell
    let cell: UITableViewCell! = self.clientTable.dequeueReusableCellWithIdentifier("tableViewCell", forIndexPath: indexPath)
    
    let messageSnapshot: FIRDataSnapshot! = self.messages[indexPath.row]
    let message = messageSnapshot.value as! Dictionary<String, String>
    let name = message[Constants.MessageFields.name] as String!
    let text = message[Constants.MessageFields.text] as String!
    
    cell!.textLabel?.text = name + ": " + text
    cell!.imageView?.image = UIImage(named: "ic_account_circle")
    
    if let imageUrl = message[Constants.MessageFields.imageUrl] {
        if imageUrl.hasPrefix("gs://") {
            FIRStorage.storage().referenceForURL(imageUrl).dataWithMaxSize(INT64_MAX){ (data, error) in
                if let error = error {
                    print("Error downloading: \(error)")
                    return
                }
                cell.imageView?.image = UIImage.init(data: data!)
            }
        } else if let url = NSURL(string:imageUrl), data = NSData(contentsOfURL: url) {
            cell.imageView?.image = UIImage.init(data: data)
        }
        cell!.textLabel?.text = "sent by: \(name)"
    } else {
        let text = message[Constants.MessageFields.text] as String!
        cell!.textLabel?.text = name + ": " + text
        cell!.imageView?.image = UIImage(named: "ic_account_circle")
        if let photoUrl = message[Constants.MessageFields.photoUrl], url = NSURL(string:photoUrl), data = NSData(contentsOfURL: url) {
            cell!.imageView?.image = UIImage(data: data)
        }
    }
    
    return cell!
  }

  // UITextViewDelegate protocol methods
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    let data = [Constants.MessageFields.text: textField.text! as String]
    sendMessage(data)
    return true
  }

  func sendMessage(data: [String: String]) {
    var mdata = data
    mdata[Constants.MessageFields.name] = AppState.sharedInstance.displayName
    if let photoUrl = AppState.sharedInstance.photoUrl {
      mdata[Constants.MessageFields.photoUrl] = photoUrl.absoluteString
    }
    self.ref.child("messages").childByAutoId().setValue(mdata)
  }

  // MARK: - Image Picker

  @IBAction func didTapAddPhoto(sender: AnyObject) {
    let picker = UIImagePickerController()
    picker.delegate = self
    if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera)) {
      picker.sourceType = UIImagePickerControllerSourceType.Camera
    } else {
      picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
    }

    presentViewController(picker, animated: true, completion:nil)
  }

  func imagePickerController(picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        picker.dismissViewControllerAnimated(true, completion:nil)
        
        let referenceUrl = info[UIImagePickerControllerReferenceURL] as! NSURL
        let assets = PHAsset.fetchAssetsWithALAssetURLs([referenceUrl], options: nil)
        let asset = assets.firstObject
        asset?.requestContentEditingInputWithOptions(nil, completionHandler: { (contentEditingInput, info) in
            let imageFile = contentEditingInput?.fullSizeImageURL
            let filePath = "\(FIRAuth.auth()?.currentUser?.uid)/\(Int(NSDate.timeIntervalSinceReferenceDate() * 1000))/\(referenceUrl.lastPathComponent!)"
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpeg"
            self.storageRef.child(filePath)
                .putFile(imageFile!, metadata: metadata) { (metadata, error) in
                    if let error = error {
                        print("Error uploading: \(error.description)")
                        return
                    }
                    self.sendMessage([Constants.MessageFields.imageUrl: self.storageRef.child((metadata?.path)!).description])
            }
        })
  }

  func imagePickerControllerDidCancel(picker: UIImagePickerController) {
    picker.dismissViewControllerAnimated(true, completion:nil)
  }

  @IBAction func signOut(sender: UIButton) {
    let firebaseAuth = FIRAuth.auth()
    
    do {
        try firebaseAuth?.signOut()
        AppState.sharedInstance.signedIn = false
    } catch let signOutError as NSError {
        print ("Error signing out: \(signOutError)")
    }
  }

  func showAlert(title:String, message:String) {
    dispatch_async(dispatch_get_main_queue()) {
        let alert = UIAlertController(title: title,
            message: message, preferredStyle: .Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .Destructive, handler: nil)
        alert.addAction(dismissAction)
        self.presentViewController(alert, animated: true, completion: nil)
    }
  }

}
