sealed class ReaderAction {}

class SelectionUpdated extends ReaderAction {
  SelectionUpdated(this.text);
  final String text;
}

class HighlightButtonTapped extends ReaderAction {}

class CopyButtonTapped extends ReaderAction {}

class AskAIButtonTapped extends ReaderAction {}

class LinkTapped extends ReaderAction {
  LinkTapped(this.href);
  final String href;
}
