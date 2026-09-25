"""Catalog serialisers shared by the admin and the public API.

The admin gets the Uzbek fields with each row's `translations` next to
them; the public views give every text in the request's language.
"""

from __future__ import annotations

from app.core.i18n import tr
from app.models.catalog import CatalogImage, PrintArea, Product, Shape, Variant, VariantColor
from app.schemas.catalog import (
    AdminAreaOut,
    AdminProductListItem,
    AdminProductOut,
    AreaMethodOut,
    AreaOut,
    ColorOut,
    ImageOut,
    PublicColor,
    PublicProductCard,
    PublicProductDetail,
    PublicShape,
    PublicVariant,
    ShapeOut,
    SizeOut,
    TierOut,
    VariantOut,
)
from app.services.catalog import (
    from_price,
    is_sellable_color,
    product_issues,
    sellable_variants,
    shape_methods,
    size_names,
)
from app.services.storage import R2Storage


def size_out(size: dict) -> SizeOut:
    return SizeOut.model_validate(size)


def public_sizes(variant: Variant) -> list[SizeOut]:
    names = size_names(variant)
    return [size_out({**s, "label": names.get(s["label"], s["label"])}) for s in variant.sizes]


def image_out(image: CatalogImage, storage: R2Storage) -> ImageOut:
    return ImageOut(media_id=image.media_id, url=storage.public_url(image.media.key), source=image.source)


def area_out(area: PrintArea) -> AreaOut:
    """An area in the request's language (the storefront and the Studio)."""
    return AreaOut(
        id=area.id, key=area.key, name=tr(area, "name"), width_mm=area.width_mm, height_mm=area.height_mm,
        anchor=area.anchor, camera=area.camera, placement_note=tr(area, "placement_note"),
        sort_order=area.sort_order, pair_key=area.pair_key, pair_mirror=area.pair_mirror,
        methods=[AreaMethodOut.model_validate(m) for m in area.methods],
    )


def admin_area_out(area: PrintArea) -> AdminAreaOut:
    return AdminAreaOut(
        id=area.id, key=area.key, name=area.name, width_mm=area.width_mm, height_mm=area.height_mm,
        anchor=area.anchor, camera=area.camera, placement_note=area.placement_note, sort_order=area.sort_order,
        pair_key=area.pair_key, pair_mirror=area.pair_mirror,
        methods=[AreaMethodOut.model_validate(m) for m in area.methods], translations=area.translations or {},
    )


def shape_out(shape: Shape, storage: R2Storage) -> ShapeOut:
    return ShapeOut(
        id=shape.id, name=shape.name, description=shape.description or "", kind=shape.kind, dims=shape.dims,
        model_url=storage.public_url(shape.model.key) if shape.model else None, model_media_id=shape.model_media_id,
        model_transform=shape.model_transform, mm_per_unit=shape.mm_per_unit, status=shape.status,
        locked=shape.locked_at is not None, archived=shape.archived_at is not None,
        replaces_id=shape.replaces_id, areas=[admin_area_out(a) for a in shape.areas],
        translations=shape.translations or {},
    )


def card_url(color: VariantColor, storage: R2Storage) -> str | None:
    """The colour's primary card picture from its gallery."""
    if color.images:
        for img in color.images:
            if img.media and img.media.key:
                return storage.public_url(img.media.key)
    return None


def card_out(color: VariantColor, storage: R2Storage) -> ImageOut | None:
    if color.images:
        for img in color.images:
            if img.media and img.media.key:
                return ImageOut(media_id=img.media_id, url=storage.public_url(img.media.key))
    return None


def color_out(color: VariantColor, storage: R2Storage) -> ColorOut:
    return ColorOut(
        id=color.id, name=color.name, hex=color.hex, surcharge=color.surcharge, is_available=color.is_available,
        sort_order=color.sort_order, archived=color.archived_at is not None,
        card_image=card_out(color, storage),
        card_media_id=None, card_image_url=card_url(color, storage),
        images=[image_out(i, storage) for i in color.images], translations=color.translations or {},
    )


def variant_out(variant: Variant, storage: R2Storage) -> VariantOut:
    main_url = variant_main_url(variant, storage)
    return VariantOut(
        id=variant.id, shape_id=variant.shape_id, name=variant.name, short_description=variant.short_description,
        description=variant.description, specs=variant.specs, base_price=variant.base_price, methods=variant.methods,
        material=variant.material, white_underbase=variant.white_underbase, is_available=variant.is_available,
        sort_order=variant.sort_order, archived=variant.archived_at is not None,
        main_image=None, main_image_media_id=None, main_image_url=main_url,
        sizes=[size_out(s) for s in variant.sizes],
        images=[image_out(i, storage) for i in variant.images],
        colors=[color_out(c, storage) for c in variant.colors],
        translations=variant.translations or {},
    )


def admin_product_out(product: Product, storage: R2Storage) -> AdminProductOut:
    return AdminProductOut(
        id=product.id, slug=product.slug, name=product.name, description=product.description,
        cover=ImageOut(media_id=product.cover.id, url=storage.public_url(product.cover.key)) if product.cover else None,
        is_featured=product.is_featured, is_available=product.is_available, archived=product.archived_at is not None,
        sort_order=product.sort_order, category=product.category, images=[image_out(i, storage) for i in product.images],
        shapes=[shape_out(s, storage) for s in product.shapes],
        variants=[variant_out(v, storage) for v in product.variants],
        price_tiers=[TierOut.model_validate(t) for t in product.price_tiers],
        sellable=bool(sellable_variants(product)),
        issues=product_issues(product),
        translations=product.translations or {},
    )


def admin_list_item(product: Product, storage: R2Storage) -> AdminProductListItem:
    sellable = sellable_variants(product)
    return AdminProductListItem(
        id=product.id, slug=product.slug, name=product.name,
        cover_url=storage.public_url(product.cover.key) if product.cover else None,
        is_featured=product.is_featured, is_available=product.is_available, archived=product.archived_at is not None,
        sort_order=product.sort_order, category=product.category, variant_count=sum(1 for v in product.variants if v.archived_at is None),
        shape_count=sum(1 for s in product.shapes if s.archived_at is None and s.replaces_id is None),
        sellable=bool(sellable), from_price=from_price(sellable, product.price_tiers) if sellable else None,
        translations=product.translations or {},
    )


def variant_main_url(variant: Variant, storage: R2Storage) -> str | None:
    for color in variant.colors:
        url = card_url(color, storage)
        if url:
            return url
    return None


def card_cover_url(product: Product, variants: list[Variant], storage: R2Storage) -> str | None:
    """What a listing card shows: the product's cover, else the first
    sellable variant's main image. A card is never left blank because
    nobody remembered to set a cover."""
    if product.cover and product.cover.key:
        return storage.public_url(product.cover.key)
    for variant in variants:
        url = variant_main_url(variant, storage)
        if url:
            return url
    return None


def public_card(product: Product, storage: R2Storage) -> PublicProductCard:
    variants = sellable_variants(product)
    return PublicProductCard(
        slug=product.slug, name=tr(product, "name"),
        cover_url=card_cover_url(product, variants, storage),
        from_price=from_price(variants, product.price_tiers), is_featured=product.is_featured,
        category=product.category,
    )


def public_detail(product: Product, storage: R2Storage) -> PublicProductDetail:
    variants = sellable_variants(product)
    shapes = {v.shape.id: v.shape for v in variants}

    # Every gallery below is exactly what the admin put there. Until recently
    # each one was topped up with Studio template mockups, so a customer
    # opening a plain black t-shirt saw shirts carrying finished prints — and
    # a colour's strip could show a different colour entirely. A picture on
    # the page now means someone chose it for that product, type or colour.
    product_images = [
        storage.public_url(i.media.key) for i in product.images if i.media and i.media.key
    ]

    # Cover, else the first picture the product has, else the first sellable
    # variant's main image — the detail page is never left imageless either.
    cover_url = (
        (storage.public_url(product.cover.key) if product.cover else None)
        or (product_images[0] if product_images else None)
        or card_cover_url(product, variants, storage)
    )

    public_variants = []
    for v in variants:
        variant_images = [
            storage.public_url(i.media.key) for i in v.images if i.media and i.media.key
        ]

        public_colors = []
        for c in v.colors:
            if not is_sellable_color(c):
                continue

            color_images = [
                storage.public_url(i.media.key) for i in c.images if i.media and i.media.key
            ]

            public_colors.append(
                PublicColor(
                    id=c.id,
                    name=tr(c, "name"),
                    hex=c.hex,
                    surcharge=c.surcharge,
                    card_image_url=card_url(c, storage),
                    images=color_images,
                )
            )

        v_main_img = variant_main_url(v, storage)
        public_variants.append(
            PublicVariant(
                id=v.id,
                shape_id=v.shape_id,
                name=tr(v, "name"),
                short_description=tr(v, "short_description"),
                description=tr(v, "description"),
                specs=tr(v, "specs"),
                base_price=v.base_price,
                methods=[m for m in v.methods if m in shape_methods(v.shape)],
                material=v.material,
                white_underbase=v.white_underbase,
                main_image_url=v_main_img,
                # Deprecated alias, one release only: the Flutter app still
                # reads `variant_main_image`.
                variant_main_image=v_main_img,
                images=variant_images,
                sizes=public_sizes(v),
                colors=public_colors,
            )
        )

    return PublicProductDetail(
        slug=product.slug,
        name=tr(product, "name"),
        description=tr(product, "description") or "",
        cover_url=cover_url,
        images=product_images,
        from_price=from_price(variants, product.price_tiers),
        variants=public_variants,
        shapes=[
            PublicShape(
                id=s.id,
                kind=s.kind,
                dims=s.dims,
                model_url=storage.public_url(s.model.key) if s.model else None,
                model_transform=s.model_transform,
                mm_per_unit=s.mm_per_unit,
                areas=[area_out(a) for a in s.areas],
            )
            for s in shapes.values()
        ],
    )


