import UIKit
import Capacitor
import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var backgroundCompletion: (() -> Void)?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool { ApplicationDelegateProxy.shared.application(app, open: url, options: options) }
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool { ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler) }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) { backgroundCompletion = completionHandler; _ = AudioEngine.shared.session }
}
class PlayerBridge: CAPBridgeViewController {
    override func capacitorDidLoad() { bridge?.registerPluginInstance(AudioEngine.shared) }
}

@objc(AudioEngine)
public class AudioEngine: CAPPlugin, CAPBridgedPlugin, URLSessionDownloadDelegate, UIDocumentPickerDelegate {
    static let shared = AudioEngine()
    public let identifier = "AudioEngine"
    public let jsName = "AudioEngine"
    public let pluginMethods: [CAPPluginMethod] = ["play","control","state","downloads","download","cancelDownload","deleteDownload","importFile","sleep","settings"].map { CAPPluginMethod(name: $0, returnType: CAPPluginReturnPromise) }
    private let player = AVPlayer()
    private var queue = [[String: String]]()
    private var index = 0
    private var rate: Float = 1
    private var repeatMode = "all"
    private var timer: Timer?
    private var sleepTimer: Timer?
    private var sleepUntil: Double = 0
    private var observation: NSKeyValueObservation?
    private var importCall: CAPPluginCall?
    private var resumeAfterInterruption = false
    private var taskMap = [String: URLSessionDownloadTask]()
    private var progress = [String: Double]()
    private var failures = [String: String]()
    private var booted = false
    private var tick = 0
    private let defaults = UserDefaults.standard
    private var current: [String:String] { queue.indices.contains(index) ? queue[index] : [:] }
    private var root: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var u = dir; var values = URLResourceValues(); values.isExcludedFromBackup = true; try? u.setResourceValues(values)
        return dir
    }
    private func safe(_ id: String) -> Bool { !id.isEmpty && id.count < 100 && id.range(of:"^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil }
    private func local(_ id: String) -> URL { root.appendingPathComponent(id + ".mp3") }
    private func bundled(_ id: String) -> URL? { let u = Bundle.main.bundleURL.appendingPathComponent("public/audio/" + id + ".mp3"); return FileManager.default.fileExists(atPath:u.path) ? u : nil }
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.mostafa.anashidi.audio.downloads")
        config.httpMaximumConnectionsPerHost = 3
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        config.allowsCellularAccess = !defaults.bool(forKey: "wifiOnly")
        let s = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        s.getAllTasks { tasks in DispatchQueue.main.async { for task in tasks { if let d = task as? URLSessionDownloadTask, let id = d.taskDescription { self.taskMap[id] = d; self.progress[id] = 0 } }; self.emitDownloads() } }
        return s
    }()
    public override func load() { setup() }
    private func setup() {
        guard !booted else { return }; booted = true
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default); try AVAudioSession.sharedInstance().setActive(true) } catch { }
        _ = session
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.addTarget { [weak self] _ in self?.player.playImmediately(atRate:self?.rate ?? 1); self?.publish(); return .success }
        remote.pauseCommand.addTarget { [weak self] _ in self?.player.pause(); self?.publish(); return .success }
        remote.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        remote.nextTrackCommand.addTarget { [weak self] _ in self?.advance(1); return .success }
        remote.previousTrackCommand.addTarget { [weak self] _ in self?.advance(-1); return .success }
        remote.changePlaybackPositionCommand.addTarget { [weak self] event in guard let e = event as? MPChangePlaybackPositionCommandEvent else {return .commandFailed}; self?.seek(e.positionTime); return .success }
        remote.skipForwardCommand.preferredIntervals = [15]; remote.skipBackwardCommand.preferredIntervals = [15]
        remote.skipForwardCommand.addTarget { [weak self] _ in self?.seek((self?.position() ?? 0)+15); return .success }
        remote.skipBackwardCommand.addTarget { [weak self] _ in self?.seek((self?.position() ?? 0)-15); return .success }
        NotificationCenter.default.addObserver(self, selector:#selector(ended), name:.AVPlayerItemDidPlayToEndTime, object:nil)
        NotificationCenter.default.addObserver(self, selector:#selector(interrupted(_:)), name:AVAudioSession.interruptionNotification, object:nil)
        NotificationCenter.default.addObserver(self, selector:#selector(routeChanged(_:)), name:AVAudioSession.routeChangeNotification, object:nil)
        timer = Timer.scheduledTimer(withTimeInterval:1, repeats:true) { [weak self] _ in guard let self = self else{return}; self.tick += 1; self.publish(); if self.tick % 5 == 0 { self.savePosition() } }
    }
    private func position() -> Double { let n = player.currentTime().seconds; return n.isFinite ? n : 0 }
    private func duration() -> Double { let n = player.currentItem?.duration.seconds ?? 0; return n.isFinite ? n : 0 }
    private func savePosition() { if let id = current["id"] { defaults.set(position(),forKey:"pos_"+id); defaults.set(current,forKey:"lastTrack") } }
    private func stateData() -> [String:Any] { ["id":current["id"] ?? "", "title":current["title"] ?? "", "artist":current["artist"] ?? "", "playing":player.rate > 0, "loading":player.timeControlStatus == .waitingToPlayAtSpecifiedRate, "position":position(),"duration":duration(),"rate":rate,"repeat":repeatMode,"sleepUntil":sleepUntil,"lastTrack":defaults.dictionary(forKey:"lastTrack") ?? [:]] }
    private func publish() {
        notifyListeners("state", data:stateData())
        guard !current.isEmpty else{return}
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle:current["title"] ?? "Anashidi",MPMediaItemPropertyArtist:current["artist"] ?? "",MPMediaItemPropertyPlaybackDuration:duration(),MPNowPlayingInfoPropertyElapsedPlaybackTime:position(),MPNowPlayingInfoPropertyPlaybackRate:player.rate]
    }
    private func start(_ resume: Bool = true) {
        guard let id = current["id"], safe(id) else{return}
        let url: URL?
        if FileManager.default.fileExists(atPath:local(id).path) { url = local(id) }
        else if let b = bundled(id) { url = b }
        else { url = URL(string:current["url"] ?? "") }
        guard let u=url, u.isFileURL || u.scheme=="https" || u.scheme=="http" else {notifyListeners("error",data:["message":"لا يوجد ملف محلي أو رابط صالح لهذا المقطع"]);return}
        try? AVAudioSession.sharedInstance().setActive(true)
        let item=AVPlayerItem(url:u)
        observation = item.observe(\.status,options:[.new]) { [weak self] item,_ in
            DispatchQueue.main.async { guard let self=self else{return}; if item.status == .failed {self.notifyListeners("error",data:["message":"تعذر تشغيل الصوت. تحقق من الإنترنت أو أعد تنزيل الملف."]);self.publish()} }
        }
        player.replaceCurrentItem(with:item)
        let saved=resume ? defaults.double(forKey:"pos_"+id) : 0
        if saved>2 {player.seek(to:CMTime(seconds:saved,preferredTimescale:600))}
        player.playImmediately(atRate:rate); defaults.set(current,forKey:"lastTrack"); publish()
    }
    private func toggle() { if player.rate>0 {player.pause();savePosition()} else {try? AVAudioSession.sharedInstance().setActive(true);player.playImmediately(atRate:rate)};publish() }
    private func seek(_ seconds: Double) {player.seek(to:CMTime(seconds:max(0,min(seconds,duration()>0 ? duration():seconds)),preferredTimescale:600));publish()}
    private func advance(_ delta: Int) {guard !queue.isEmpty else{return};savePosition();index=(index+delta+queue.count)%queue.count;start(false)}
    @objc private func ended() {guard let id=current["id"] else{return};defaults.set(0,forKey:"pos_"+id);if repeatMode=="one"{start(false)}else if index+1<queue.count{index+=1;start(false)}else if repeatMode=="all"{index=0;start(false)}else{player.pause();publish()}}
    @objc private func interrupted(_ note:Notification) {guard let raw=note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else{return};if raw==AVAudioSession.InterruptionType.began.rawValue {resumeAfterInterruption=player.rate>0;player.pause();savePosition()}else if let options=note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt, AVAudioSession.InterruptionOptions(rawValue:options).contains(.shouldResume),resumeAfterInterruption {try? AVAudioSession.sharedInstance().setActive(true);player.playImmediately(atRate:rate)};publish()}
    @objc private func routeChanged(_ note:Notification) {if let raw=note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,raw==AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue{player.pause();publish()}}
    @objc func play(_ call:CAPPluginCall) {DispatchQueue.main.async {self.setup();self.savePosition();guard let entries=call.options["queue"] as? [[String:String]],!entries.isEmpty,entries.allSatisfy({self.safe($0["id"] ?? "")}) else{call.reject("قائمة تشغيل غير صالحة");return};self.queue=entries;self.index=max(0,min(call.getInt("index") ?? 0,entries.count-1));self.start(call.getBool("resume") ?? true);call.resolve(self.stateData())}}
    @objc func control(_ call:CAPPluginCall) {DispatchQueue.main.async {switch call.getString("action") ?? "" {case "toggle":self.toggle();case "next":self.advance(1);case "previous":self.advance(-1);case "seek":self.seek(call.getDouble("seconds") ?? 0);case "pause":self.player.pause();self.savePosition();default:break};call.resolve(self.stateData())}}
    @objc func state(_ call:CAPPluginCall) {DispatchQueue.main.async {self.setup();call.resolve(self.stateData())}}
    @objc func settings(_ call:CAPPluginCall) {DispatchQueue.main.async {if let r=call.getDouble("rate"){self.rate=Float(max(0.5,min(2,r)));if self.player.rate>0{self.player.rate=self.rate}};if let r=call.getString("repeat"){self.repeatMode=r};if let w=call.getBool("wifiOnly"){self.defaults.set(w,forKey:"wifiOnly")};call.resolve()}}
    @objc func sleep(_ call:CAPPluginCall) {DispatchQueue.main.async {self.sleepTimer?.invalidate();let minutes=call.getDouble("minutes") ?? 0;self.sleepUntil=minutes>0 ? Date().timeIntervalSince1970+minutes*60 : 0;if minutes>0 {self.sleepTimer=Timer.scheduledTimer(withTimeInterval:minutes*60,repeats:false){_ in self.player.pause();self.savePosition();self.sleepUntil=0;self.publish()}};self.publish();call.resolve()}}
    private func downloadData() -> [String:Any] {
        var items=[[String:Any]]()
        for url in (try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.fileSizeKey])) ?? [] where url.pathExtension=="mp3" {
            items.append(["id":url.deletingPathExtension().lastPathComponent,"bytes":(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0,"bundled":false])
        }
        let assets=Bundle.main.bundleURL.appendingPathComponent("public/audio")
        for url in (try? FileManager.default.contentsOfDirectory(at:assets,includingPropertiesForKeys:[.fileSizeKey])) ?? [] where url.pathExtension=="mp3" {items.append(["id":url.deletingPathExtension().lastPathComponent,"bytes":(try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0,"bundled":true])}
        return ["items":items,"progress":progress,"failures":failures,"wifiOnly":defaults.bool(forKey:"wifiOnly")]
    }
    private func emitDownloads() {notifyListeners("downloads",data:downloadData())}
    @objc func downloads(_ call:CAPPluginCall) {DispatchQueue.main.async {self.setup();call.resolve(self.downloadData())}}
    @objc func download(_ call:CAPPluginCall) {DispatchQueue.main.async {
        guard let entries=call.options["items"] as? [[String:String]] else{call.reject("ملفات غير صالحة");return}
        var count=0
        for entry in entries {
            guard let id=entry["id"],self.safe(id),let value=entry["url"],let url=URL(string:value),["https","http"].contains(url.scheme ?? ""),self.taskMap[id]==nil,!FileManager.default.fileExists(atPath:self.local(id).path),self.bundled(id)==nil else{continue}
            var request=URLRequest(url:url);request.allowsCellularAccess = !self.defaults.bool(forKey:"wifiOnly")
            let task=self.session.downloadTask(with:request);task.taskDescription=id;self.taskMap[id]=task;self.progress[id]=0;self.failures.removeValue(forKey:id);task.resume();count+=1
        };self.emitDownloads();call.resolve(["queued":count])
    }}
    @objc func cancelDownload(_ call:CAPPluginCall) {DispatchQueue.main.async {let id=call.getString("id") ?? "";if id=="all"{for task in self.taskMap.values{task.cancel()};self.taskMap.removeAll();self.progress.removeAll()}else{self.taskMap[id]?.cancel();self.taskMap.removeValue(forKey:id);self.progress.removeValue(forKey:id)};self.emitDownloads();call.resolve()}}
    @objc func deleteDownload(_ call:CAPPluginCall) {DispatchQueue.main.async {guard let id=call.getString("id"),self.safe(id) else{call.reject("ملف غير صالح");return};do{if FileManager.default.fileExists(atPath:self.local(id).path){try FileManager.default.removeItem(at:self.local(id))};self.emitDownloads();call.resolve()}catch{call.reject("تعذر حذف الملف")}}}
    public func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {guard let id=downloadTask.taskDescription else{return};progress[id]=totalBytesExpectedToWrite>0 ? Double(totalBytesWritten)/Double(totalBytesExpectedToWrite):0;emitDownloads()}
    public func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {
        guard let id=downloadTask.taskDescription,safe(id) else{return}
        do {
            guard let response=downloadTask.response as? HTTPURLResponse,(200...299).contains(response.statusCode) else{throw NSError(domain:"HTTP",code:1)}
            let mime=downloadTask.response?.mimeType ?? "";guard !mime.contains("text/") && !mime.contains("html") && !mime.contains("json") else{throw NSError(domain:"Audio",code:2)}
            let asset=AVURLAsset(url:location);guard !asset.tracks(withMediaType:.audio).isEmpty else{throw NSError(domain:"Audio",code:3)}
            if FileManager.default.fileExists(atPath:local(id).path){try FileManager.default.removeItem(at:local(id))};try FileManager.default.moveItem(at:location,to:local(id));failures.removeValue(forKey:id)
        }catch{failures[id]="تعذر حفظ صوت صالح. أعد المحاولة وتحقق من الرابط والمساحة."}
        progress.removeValue(forKey:id);taskMap.removeValue(forKey:id);emitDownloads()
    }
    public func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) {guard let id=task.taskDescription else{return};if let error=error as NSError?,error.code != NSURLErrorCancelled{failures[id]="فشل التنزيل. تحقق من الشبكة والمساحة ثم أعد المحاولة."};progress.removeValue(forKey:id);taskMap.removeValue(forKey:id);emitDownloads()}
    public func urlSessionDidFinishEvents(forBackgroundURLSession session:URLSession) {DispatchQueue.main.async {if let app=UIApplication.shared.delegate as? AppDelegate{app.backgroundCompletion?();app.backgroundCompletion=nil}}}
    @objc func importFile(_ call:CAPPluginCall) {DispatchQueue.main.async {guard self.importCall==nil else{call.reject("الاستيراد مفتوح");return};self.importCall=call;let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.audio],asCopy:true);picker.delegate=self;self.bridge?.viewController?.present(picker,animated:true)}}
    public func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController){importCall?.resolve(["cancelled":true]);importCall=nil}
    public func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]) {defer{importCall=nil};guard let url=urls.first else{return};let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}};do{let id="local-"+UUID().uuidString;let asset=AVURLAsset(url:url);guard !asset.tracks(withMediaType:.audio).isEmpty else{throw NSError(domain:"Audio",code:3)};try FileManager.default.copyItem(at:url,to:local(id));importCall?.resolve(["id":id,"title":url.deletingPathExtension().lastPathComponent,"url":"","artist":"من ملفاتي","kind":"nasheed"]);emitDownloads()}catch{importCall?.reject("تعذر استيراد الملف الصوتي")}}
}
