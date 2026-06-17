import 'package:web/web.dart' as web;

void updatePageSeo({
  required String title,
  required String description,
  String? imageUrl,
  String? canonicalUrl,
}) {
  web.document.title = title;
  _setMeta(name: 'description', content: description);
  _setMeta(property: 'og:title', content: title);
  _setMeta(property: 'og:description', content: description);
  _setMeta(property: 'og:type', content: 'website');
  if (imageUrl != null && imageUrl.isNotEmpty) {
    _setMeta(property: 'og:image', content: imageUrl);
  }
  if (canonicalUrl != null && canonicalUrl.isNotEmpty) {
    _setMeta(property: 'og:url', content: canonicalUrl);
    _setLink(rel: 'canonical', href: canonicalUrl);
  }
}

void resetPageSeo() {
  web.document.title = 'Turistar Viagens Premium';
  _setMeta(name: 'description', content: 'Turistar Viagens Premium - passagens, hoteis, pacotes e cotacoes via WhatsApp.');
}

void _setMeta({String? name, String? property, required String content}) {
  final selector = property != null ? 'meta[property="$property"]' : 'meta[name="$name"]';
  web.Element? element = web.document.querySelector(selector);
  if (element == null) {
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    if (property != null) {
      meta.setAttribute('property', property);
    } else if (name != null) {
      meta.name = name;
    }
    web.document.head?.append(meta);
    element = meta;
  }
  element.setAttribute('content', content);
}

void _setLink({required String rel, required String href}) {
  final selector = 'link[rel="$rel"]';
  web.Element? element = web.document.querySelector(selector);
  if (element == null) {
    final link = web.document.createElement('link') as web.HTMLLinkElement;
    link.rel = rel;
    web.document.head?.append(link);
    element = link;
  }
  element.setAttribute('href', href);
}
