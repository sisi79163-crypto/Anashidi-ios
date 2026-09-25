from pathlib import Path
import plistlib,shutil
app=Path('ios/App/App')
shutil.copyfile('native/AppDelegate.swift',app/'AppDelegate.swift')
p=app/'Base.lproj/Main.storyboard'
s=p.read_text().replace('customClass="CAPBridgeViewController" customModule="Capacitor"','customClass="PlayerBridge" customModule="App" customModuleProvider="target"')
assert 'customClass="PlayerBridge"' in s,'Storyboard class not found'
p.write_text(s)
p=app/'Info.plist'
d=plistlib.loads(p.read_bytes());d['CFBundleDisplayName']='Anashidi';d['CFBundleName']='Anashidi';d['UIBackgroundModes']=['audio'];d['NSAppTransportSecurity']={'NSAllowsArbitraryLoads':True};d['LSApplicationCategoryType']='public.app-category.music'
p.write_bytes(plistlib.dumps(d))
