import '../../../core/utils/money.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/design_document.dart';
import '../domain/editor_models.dart';
import '../domain/print_area.dart';

enum EditorPhase { loading, ready, failed }

enum SaveStatus { idle, pending, saving, saved, error }

/// Adding to the cart, step by step.
sealed class CartFlow {
  const CartFlow();
}

class CartIdle extends CartFlow {
  const CartIdle();
}

class CartWorking extends CartFlow {
  const CartWorking(this.step, [this.progress]);
  final String step;

  /// Share of the steps done (0..1), null when unknown.
  final double? progress;
}

/// The print files priced differently: the customer confirms [quote].
class CartConfirm extends CartFlow {
  const CartConfirm(this.quote, this.message);
  final Quote quote;
  final String message;
}

class CartDone extends CartFlow {
  const CartDone();
}

class CartFailed extends CartFlow {
  const CartFailed(this.message);
  final String message;
}

class EditorArgs {
  const EditorArgs({required this.slug, this.variantId, this.colorId, this.size, this.designId, this.templateId});

  final String slug;
  final int? variantId;
  final int? colorId;
  final String? size;
  final String? designId;

  /// A gallery design to start from.
  final int? templateId;

  @override
  bool operator ==(Object other) =>
      other is EditorArgs &&
      other.slug == slug &&
      other.variantId == variantId &&
      other.colorId == colorId &&
      other.size == size &&
      other.designId == designId &&
      other.templateId == templateId;

  @override
  int get hashCode => Object.hash(slug, variantId, colorId, size, designId, templateId);
}

class EditorState {
  EditorState({
    this.phase = EditorPhase.loading,
    this.error,
    this.product,
    this.variantId,
    this.colorId,
    this.size,
    this.doc = DesignDocument.empty,
    this.selectedArea,
    this.selectedLayer,
    this.designId,
    this.version = 0,
    this.quote,
    this.saveStatus = SaveStatus.idle,
    this.saveError,
    this.preferredMethod,
    this.surfaceColors = const {},
    this.engraveTint,
    this.canUndo = false,
    this.canRedo = false,
    this.uploads = const [],
    this.notice,
    this.cart = const CartIdle(),
    this.hiddenAreas = const {},
  });

  final EditorPhase phase;
  final Object? error;
  final ProductDetail? product;
  final int? variantId;
  final int? colorId;
  final String? size;
  final DesignDocument doc;
  final String? selectedArea;
  final String? selectedLayer;
  final String? designId;
  final int version;
  final Quote? quote;
  final SaveStatus saveStatus;
  final String? saveError;
  final String? preferredMethod;

  /// The colour each area is printed on (from the 3D model).
  final Map<String, String> surfaceColors;
  final String? engraveTint;
  final bool canUndo;
  final bool canRedo;

  /// Pictures uploaded in this session ("Rasm" offers them again).
  final List<ImageSource> uploads;

  /// A one-off message for a snackbar (cleared once shown).
  final String? notice;
  final CartFlow cart;

  /// Layers hidden with "Yashirish" (parked): id → the area they came from.
  final Map<String, String> hiddenAreas;

  static const _keep = Object();

  EditorState copyWith({
    EditorPhase? phase,
    Object? error = _keep,
    ProductDetail? product,
    Object? variantId = _keep,
    Object? colorId = _keep,
    Object? size = _keep,
    DesignDocument? doc,
    Object? selectedArea = _keep,
    Object? selectedLayer = _keep,
    Object? designId = _keep,
    int? version,
    Object? quote = _keep,
    SaveStatus? saveStatus,
    Object? saveError = _keep,
    Object? preferredMethod = _keep,
    Map<String, String>? surfaceColors,
    Object? engraveTint = _keep,
    bool? canUndo,
    bool? canRedo,
    List<ImageSource>? uploads,
    Object? notice = _keep,
    CartFlow? cart,
    Map<String, String>? hiddenAreas,
  }) {
    T pick<T>(Object? v, T current) => identical(v, _keep) ? current : v as T;
    return EditorState(
      phase: phase ?? this.phase,
      error: pick(error, this.error),
      product: product ?? this.product,
      variantId: pick(variantId, this.variantId),
      colorId: pick(colorId, this.colorId),
      size: pick(size, this.size),
      doc: doc ?? this.doc,
      selectedArea: pick(selectedArea, this.selectedArea),
      selectedLayer: pick(selectedLayer, this.selectedLayer),
      designId: pick(designId, this.designId),
      version: version ?? this.version,
      quote: pick(quote, this.quote),
      saveStatus: saveStatus ?? this.saveStatus,
      saveError: pick(saveError, this.saveError),
      preferredMethod: pick(preferredMethod, this.preferredMethod),
      surfaceColors: surfaceColors ?? this.surfaceColors,
      engraveTint: pick(engraveTint, this.engraveTint),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      uploads: uploads ?? this.uploads,
      notice: pick(notice, this.notice),
      cart: cart ?? this.cart,
      hiddenAreas: hiddenAreas ?? this.hiddenAreas,
    );
  }

  // ── Derived ──

  late final ProductVariant? variant = product?.variantById(variantId);
  late final ProductColor? color = variant?.colorById(colorId);
  late final List<VariantSize> sizesInStock = [for (final s in variant?.sizes ?? const <VariantSize>[]) if (s.isAvailable) s];
  late final VariantSize? sizeInfo = () {
    for (final s in sizesInStock) {
      if (s.label == size) return s;
    }
    return null;
  }();

  /// Sold by size: one must be chosen before the cart.
  bool get needsSize => sizesInStock.isNotEmpty;

  late final List<PrintArea> areas = areasOf(product, variant);
  late final List<String> methods = [for (final m in variant?.methods ?? const <PrintMethod>[]) m.value];
  late final PrintArea? area = areaByKey(areas, selectedArea);
  late final Layer? layer = doc.byId(selectedLayer);
  late final List<Layer> effective = effectiveLayers(doc, areas);

  /// Where the laser strips stand (a synced area's copies use the centred rule).
  List<PrintStrip> get strips => doc.strips;
  late final String? designMethod = designMethodOf(doc.layers, methods, preferredMethod);
  late final Map<String, List<String>> problems = designProblems(effective, areas, methods, designMethod, strips);
  late final int problemTotal = problemCount(problems);
  late final int croppedCount =
      effective.where((l) => !isCopy(l.id) && sticksOut(l, areas, effective, strips)).length;
  int get placedCount => effective.length;
  bool get blocked => problemTotal > 0 || placedCount == 0;

  /// The surface under the open area.
  String get surfaceHex => surfaceColors[selectedArea] ?? color?.hex ?? '#ffffff';

  /// Default ink of new text and graphics on that surface.
  String get inkColor => contrastInk(surfaceHex);

  String get engraveColor => engraveTint ?? engraveTints[variant?.material] ?? '#3f3f46';

  /// The area the open one is synced from (it is read-only then).
  PrintArea? get linkedFrom => areaByKey(areas, selectedArea == null ? null : doc.syncedFrom(selectedArea!));

  /// The method a new layer in [areaKey] gets: the design's, if the area has it.
  String? defaultMethod(String areaKey) {
    final a = areaByKey(areas, areaKey);
    final m = designMethod;
    return a != null && m != null && a.method(m) != null ? m : null;
  }

  bool get canAdd => area != null && linkedFrom == null && defaultMethod(area!.key) != null;

  /// A colour fill under the design is possible.
  bool get canBackground {
    final hex = color?.hex.toLowerCase();
    return hex != null &&
        designMethod == 'uv' &&
        areas.any((a) => a.method('uv') != null && (surfaceColors[a.key] ?? '#ffffff').toLowerCase() != hex);
  }

  /// The backend's quote when it is for the current choice.
  Quote? get liveQuote => quote != null && quote!.matches(variantId, colorId, size) ? quote : null;

  /// Shown right away from the catalog until the backend's quote arrives.
  Money? get provisionalPrice {
    final v = variant;
    final c = color;
    if (v == null || c == null) return null;
    return Money.of(
      v.basePrice.amount + c.surcharge.amount + (sizeInfo?.surcharge.amount ?? 0) + (quote?.methodsSurcharge ?? 0),
    );
  }

  Money? get price => liveQuote?.unitPrice ?? provisionalPrice;
}

/// The variant's print areas, in order.
List<PrintArea> areasOf(ProductDetail? product, ProductVariant? variant) {
  if (product == null || variant == null) return const [];
  for (final s in product.shapes) {
    if (s.id == variant.shapeId) {
      final list = [
        for (final a in (s.raw['areas'] as List?) ?? const [])
          if (a is Map) PrintArea.fromJson(Map<String, dynamic>.from(a)),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    }
  }
  return const [];
}
