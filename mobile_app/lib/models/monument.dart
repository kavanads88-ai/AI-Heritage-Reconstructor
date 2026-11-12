/// Typed model of a monument record (matches historical_data/monuments.json
/// plus the `assets` block the backend adds). Parsing is tolerant of missing
/// optional fields so the UI can show "not available" instead of crashing.
library;

enum VerificationStatus { verified, secondarySourceChecked, pending }

VerificationStatus parseVerification(String? raw) {
  switch (raw) {
    case 'verified':
      return VerificationStatus.verified;
    case 'secondary_source_checked':
      return VerificationStatus.secondarySourceChecked;
    default:
      return VerificationStatus.pending; // anything unknown is treated as unverified
  }
}

String _str(Object? v, [String fallback = '']) =>
    (v is String && v.trim().isNotEmpty) ? v : fallback;

String? _optStr(Object? v) => (v is String && v.trim().isNotEmpty) ? v : null;

class Fact {
  const Fact({required this.text, required this.status, this.sourceIds = const <String>[]});

  final String text;
  final VerificationStatus status;
  final List<String> sourceIds;

  factory Fact.fromJson(Object? json) {
    if (json is String) {
      // Legacy plain-string fact: treat as unverified.
      return Fact(text: json, status: VerificationStatus.pending);
    }
    final Map<String, dynamic> m = json as Map<String, dynamic>;
    return Fact(
      text: _str(m['text']),
      status: parseVerification(m['status'] as String?),
      sourceIds: ((m['source_ids'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }
}

class Source {
  const Source({required this.id, required this.title, required this.url, this.type = ''});

  final String id;
  final String title;
  final String url;
  final String type;

  factory Source.fromJson(Map<String, dynamic> m) => Source(
        id: _str(m['id']),
        title: _str(m['title'], 'Untitled source'),
        url: _str(m['url']),
        type: _str(m['type']),
      );
}

class ElementNote {
  const ElementNote({required this.element, required this.status, required this.source});

  final String element;
  final String status;
  final String source;

  factory ElementNote.fromJson(Map<String, dynamic> m) => ElementNote(
        element: _str(m['element'], 'Unnamed element'),
        status: _str(m['status']),
        source: _str(m['source']),
      );
}

class MonumentAssets {
  const MonumentAssets({
    this.thumbnailUrl,
    this.presentImageUrl,
    this.reconstructionImageUrl,
    this.hasModel = false,
    this.modelUrl,
  });

  final String? thumbnailUrl;
  final String? presentImageUrl;
  final String? reconstructionImageUrl;
  final bool hasModel;
  final String? modelUrl;

  factory MonumentAssets.fromJson(Map<String, dynamic> m) => MonumentAssets(
        thumbnailUrl: _optStr(m['thumbnail_url']),
        presentImageUrl: _optStr(m['present_image_url']),
        reconstructionImageUrl: _optStr(m['reconstruction_image_url']),
        hasModel: m['has_model'] == true,
        modelUrl: _optStr(m['model_url']),
      );
}

class Monument {
  const Monument({
    required this.id,
    required this.name,
    this.location = '',
    this.period = '',
    this.summary = '',
    this.architecturalSignificance = '',
    this.facts = const <Fact>[],
    this.sources = const <Source>[],
    this.documentedElements = const <ElementNote>[],
    this.hypotheticalElements = const <ElementNote>[],
    this.reconstructionTarget = 'secondary',
    this.reconstructionExplanation = '',
    this.hasDetails = true,
    this.modelFile,
    this.arModelUrl,
    this.assets = const MonumentAssets(),
    this.offlineCopy = false,
  });

  final String id;
  final String name;
  final String location;
  final String period;
  final String summary;
  final String architecturalSignificance;
  final List<Fact> facts;
  final List<Source> sources;
  final List<ElementNote> documentedElements;
  final List<ElementNote> hypotheticalElements;
  final String reconstructionTarget; // 'primary' | 'secondary'
  final String reconstructionExplanation;

  /// false for list-endpoint summaries that carry no history text.
  final bool hasDetails;
  final String? modelFile;

  /// Optional public https URL of the GLB for Android Scene Viewer (AR).
  final String? arModelUrl;
  final MonumentAssets assets;

  /// true when this record came from the bundled JSON because the backend was unreachable.
  final bool offlineCopy;

  bool get isPrimary => reconstructionTarget == 'primary';

  /// Backend summary (`GET /monuments` items).
  factory Monument.fromSummaryJson(Map<String, dynamic> m) => Monument(
        id: m['id'] as String,
        name: m['name'] as String,
        location: _str(m['location']),
        hasDetails: false,
        assets: MonumentAssets(thumbnailUrl: _optStr(m['thumbnail'])),
      );

  /// Full record (`GET /monuments/{id}` or bundled JSON).
  factory Monument.fromJson(Map<String, dynamic> m, {bool offlineCopy = false}) {
    final Object? assetsJson = m['assets'];
    return Monument(
      id: m['id'] as String,
      name: m['name'] as String,
      location: _str(m['location']),
      period: _str(m['period']),
      summary: _str(m['summary']),
      architecturalSignificance: _str(m['architectural_significance']),
      facts: ((m['facts'] as List<dynamic>?) ?? const <dynamic>[])
          .map<Fact>(Fact.fromJson)
          .toList(),
      sources: ((m['sources'] as List<dynamic>?) ?? const <dynamic>[])
          .map<Source>((dynamic e) => Source.fromJson(e as Map<String, dynamic>))
          .toList(),
      documentedElements: ((m['documented_elements'] as List<dynamic>?) ?? const <dynamic>[])
          .map<ElementNote>((dynamic e) => ElementNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      hypotheticalElements: ((m['hypothetical_elements'] as List<dynamic>?) ?? const <dynamic>[])
          .map<ElementNote>((dynamic e) => ElementNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      reconstructionTarget: _str(m['reconstruction_target'], 'secondary'),
      reconstructionExplanation: _str(m['reconstruction_explanation']),
      modelFile: _optStr(m['model_file']),
      arModelUrl: _optStr(m['ar_model_url']),
      assets: assetsJson is Map<String, dynamic>
          ? MonumentAssets.fromJson(assetsJson)
          : const MonumentAssets(),
      offlineCopy: offlineCopy,
    );
  }

  Monument copyWith({bool? offlineCopy, MonumentAssets? assets}) => Monument(
        id: id,
        name: name,
        location: location,
        period: period,
        summary: summary,
        architecturalSignificance: architecturalSignificance,
        facts: facts,
        sources: sources,
        documentedElements: documentedElements,
        hypotheticalElements: hypotheticalElements,
        reconstructionTarget: reconstructionTarget,
        reconstructionExplanation: reconstructionExplanation,
        hasDetails: hasDetails,
        modelFile: modelFile,
        arModelUrl: arModelUrl,
        assets: assets ?? this.assets,
        offlineCopy: offlineCopy ?? this.offlineCopy,
      );
}
