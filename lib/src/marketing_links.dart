/// Public website configuration only. No account, career or device identifier
/// is attached to a discovery link.
final class StudioMarketingLinks {
  const StudioMarketingLinks({this.websiteBaseUrl = ''});

  const StudioMarketingLinks.fromEnvironment()
    : websiteBaseUrl = const String.fromEnvironment(
        'ELEVENWARD_STUDIO_WEBSITE_URL',
      );

  final String websiteBaseUrl;

  Uri? get _origin {
    final uri = Uri.tryParse(websiteBaseUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri;
  }

  Uri? get productUrl => _origin?.resolve('/elevenward/');

  Uri? get careerShareUrl => productUrl?.replace(
    queryParameters: const {
      'utm_source': 'elevenward',
      'utm_medium': 'share',
      'utm_campaign': 'career-share-v1',
    },
  );

  // The live studio homepage already lists the portfolio. This link stays
  // useful before a separate games directory is published.
  Uri? get studioDiscoveryUrl => _origin
      ?.resolve('/')
      .replace(
        queryParameters: const {
          'utm_source': 'elevenward',
          'utm_medium': 'cross-promotion',
          'utm_campaign': 'portfolio-v1',
        },
      );

  String? get productDisplayUrl =>
      productUrl?.toString().replaceFirst('https://', '');
}
