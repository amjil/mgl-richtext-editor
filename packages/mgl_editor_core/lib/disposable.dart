/// A simple disposable class that can be used with ClojureDart's :managed
class Disposable {
  final void Function() disposeFn;

  Disposable(this.disposeFn);

  void dispose() {
    disposeFn();
  }
}




