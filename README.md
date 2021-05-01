## Usage




```
import 'package:memory_checker/memory_checker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      ...
      navigatorObservers: [
        LeakObserver()
      ],
    );
  }
}
```


`LeakObserver` will notify if there are some leaks found by VMService

Welcome for pr: https://github.com/asjqkkkk/memory_checker/compare


Welcome for issue:
https://github.com/asjqkkkk/memory_checker/issues/new

## Notice

If you meet this error: **Bad state: Insecure HTTP is not allowed by platform**

you need add some file to solve this problem

### Android

This behavior may be omitted following migration guide: https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android.

 add in **android/app/src/main/AndroidManifest.xml:**
 
 
```
<application
        android:name="io.flutter.app.FlutterApplication"
        android:label="receipt"
        android:usesCleartextTraffic="true" <!-- This Line -->
        android:icon="@mipmap/ic_launcher">
```

### iOS

Allow insecure/HTTP requests globally across your application on iOS, you can add this to your **ios/Runner/info.plist** under the main dictionary definition:


```
<key>NSAppTransportSecurity</key>
<dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
</dict>
```

Be warned that you will need to have an explanation for Apple's review team when enabling this, otherwise your app will get rejected on submission.

(see [Bad state: Insecure HTTP is not allowed by platform](https://stackoverflow.com/questions/64197752/bad-state-insecure-http-is-not-allowed-by-platform))

## Performance

If there is a page leak:

![image](https://user-images.githubusercontent.com/30992818/116781148-b0fa6580-aab3-11eb-96ca-12bc67605ed9.png)

Then tap it:

![image](https://user-images.githubusercontent.com/30992818/116781231-3ed65080-aab4-11eb-99cd-bb457b623bfc.png)

And you can see the leak retainpath:


![image](https://user-images.githubusercontent.com/30992818/116783102-70084e00-aabf-11eb-87b0-f15a64fda6ea.png)