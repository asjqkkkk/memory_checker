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