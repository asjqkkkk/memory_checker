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
