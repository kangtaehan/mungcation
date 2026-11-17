import 'dart:js_interop';

@JS('window.open')
external JSAny? _open(String url, String target, String features);

void openBrowserLink(String url) {
  _open(url, '_blank', 'noopener,noreferrer');
}
