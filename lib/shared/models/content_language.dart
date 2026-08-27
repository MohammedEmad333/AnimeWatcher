/// Language of the episode servers to request from the backend.
///
/// The [code] is sent to the API (`?lang=ar|en`) and [label] is shown in the
/// UI toggle.
enum ContentLanguage {
  arabic('ar', 'العربية'),
  english('en', 'English');

  const ContentLanguage(this.code, this.label);

  final String code;
  final String label;
}
