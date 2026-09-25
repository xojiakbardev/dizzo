"""Content in three languages: the admin writes Russian and English next to
the Uzbek fields, the storefront reads the request's language (Uzbek when a
translation is missing), and an order line keeps the names it was bought under.
"""

import httpx
import pytest
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.models.commerce import Order
from tests.conftest import FakeStorage
from tests.test_catalog import A, build_mug, catalog_image, ok
from tests.test_sizes import add_item, as_admin, as_customer, set_sizes
from tests.test_studio import shop

RU = {"Accept-Language": "ru-RU,ru;q=0.9,en;q=0.5"}
VARIANT_TEXTS = {
    "ru": {
        "name": "Хамелеон", "short_description": "Меняет цвет",
        "description": "<p>Кружка</p><script>alert(1)</script>",
        "specs": [{"label": "Объём", "value": "330 мл"}],
        "sizes": [{"label": "Katta", "name": "Большой"}],
    },
    "en": {"name": "Chameleon", "specs": [{"label": "Volume", "value": "330 ml"}]},
}


async def translated_mug(client: httpx.AsyncClient, storage: FakeStorage) -> dict:
    product = await build_mug(client, storage)
    pid, variant = product["id"], product["variants"][0]
    ok(await client.patch(f"{A}/products/{pid}/", json={"translations": {"ru": {"name": "Кружка"}, "en": {"name": "Mug"}}}))
    ok(await client.patch(f"{A}/variants/{variant['id']}/", json={"translations": VARIANT_TEXTS}))
    black = next(c for c in variant["colors"] if c["name"] == "Qora")
    ok(await client.patch(f"{A}/colors/{black['id']}/", json={"translations": {"ru": {"name": "Чёрный"}}}))
    await set_sizes(client, variant["id"], [
        {"label": "Katta", "surcharge": "0", "is_available": True},
        {"label": "XL", "surcharge": "0", "is_available": True},
    ])
    return ok(await client.get(f"{A}/products/{pid}/"))


@pytest.mark.asyncio
async def test_the_admin_writes_translations_and_gets_them_back(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await translated_mug(admin_client, storage)
    variant = product["variants"][0]
    black = next(c for c in variant["colors"] if c["name"] == "Qora")

    # The admin reads Uzbek in the fields, whatever language it asks in.
    again = ok(await admin_client.get(f"{A}/products/{product['id']}/", headers=RU))
    assert again["name"] == "Krujka" and again["translations"]["ru"]["name"] == "Кружка"
    assert variant["name"] == "Xameleon"
    ru = variant["translations"]["ru"]
    assert ru["specs"] == [{"label": "Объём", "value": "330 мл"}]
    assert ru["sizes"] == [{"label": "Katta", "name": "Большой"}]
    assert "<script>" not in ru["description"]  # rich text is cleaned in every language
    assert black["translations"] == {"ru": {"name": "Чёрный"}}

    created = ok(await admin_client.post(f"{A}/variants/{variant['id']}/colors/", json={
        "name": "Oq", "hex": "#ffffff", "translations": {"ru": {"name": "Белый"}, "en": {"name": " "}},
    }), 201)
    white = next(c for c in created["variants"][0]["colors"] if c["name"] == "Oq")
    assert white["translations"] == {"ru": {"name": "Белый"}}  # blanks are dropped

    unknown_field = await admin_client.patch(f"{A}/products/{product['id']}/", json={"translations": {"ru": {"slug": "x"}}})
    unknown_language = await admin_client.patch(f"{A}/products/{product['id']}/", json={"translations": {"de": {"name": "x"}}})
    bad_spec = await admin_client.patch(f"{A}/variants/{variant['id']}/", json={"translations": {"ru": {"specs": [{"label": "x"}]}}})
    assert unknown_field.status_code == unknown_language.status_code == bad_spec.status_code == 422


@pytest.mark.asyncio
async def test_a_patch_merges_the_languages_it_sends(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await translated_mug(admin_client, storage)
    pid, vid = product["id"], product["variants"][0]["id"]

    patched = ok(await admin_client.patch(f"{A}/products/{pid}/", json={"translations": {"en": {"name": "Cup"}}}))
    untouched = ok(await admin_client.patch(f"{A}/variants/{vid}/", json={"name": "Xameleon 2"}))

    assert patched["translations"] == {"ru": {"name": "Кружка"}, "en": {"name": "Cup"}}
    assert untouched["variants"][0]["translations"]["en"]["name"] == "Chameleon"
    assert untouched["variants"][0]["name"] == "Xameleon 2"


@pytest.mark.asyncio
async def test_the_storefront_speaks_the_request_language(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    product = await translated_mug(admin_client, storage)
    variant = product["variants"][0]
    black = next(c for c in variant["colors"] if c["name"] == "Qora")

    uz = ok(await admin_client.get("/api/catalog/products/krujka/"))
    ru = ok(await admin_client.get("/api/catalog/products/krujka/", headers=RU))
    en = ok(await admin_client.get("/api/catalog/products/krujka/?lang=en", headers=RU))
    cards = ok(await admin_client.get("/api/catalog/products/?lang=en"))

    assert (uz["name"], ru["name"], en["name"], cards[0]["name"]) == ("Krujka", "Кружка", "Mug", "Mug")
    assert (uz["variants"][0]["name"], ru["variants"][0]["name"], en["variants"][0]["name"]) == (
        "Xameleon", "Хамелеон", "Chameleon"
    )
    assert ru["variants"][0]["specs"] == [{"label": "Объём", "value": "330 мл"}]
    assert uz["variants"][0]["specs"] == [{"label": "Hajmi", "value": "330 ml"}]
    # Missing in English: the Uzbek text.
    assert en["variants"][0]["short_description"] == uz["variants"][0]["short_description"]
    colours = {c["id"]: c["name"] for c in ru["variants"][0]["colors"]}
    assert colours[black["id"]] == "Чёрный" and "Qizil" in colours.values()
    # A word is translated, a code stays.
    assert [s["label"] for s in ru["variants"][0]["sizes"]] == ["Большой", "XL"]
    assert [s["label"] for s in en["variants"][0]["sizes"]] == ["Katta", "XL"]

    # Either spelling picks the size; the quote answers in the request's.
    body = {"variant_id": variant["id"], "color_id": black["id"], "quantity": 1}
    by_ru = ok(await admin_client.post("/api/catalog/quote/", json={**body, "size": "Большой"}, headers=RU))
    by_uz = ok(await admin_client.post("/api/catalog/quote/", json={**body, "size": "Katta"}))
    assert (by_ru["size"], by_uz["size"]) == ("Большой", "Katta")


@pytest.mark.asyncio
async def test_categories_and_tutorials_are_translated(admin_client: httpx.AsyncClient, storage: FakeStorage) -> None:
    categories = ok(await admin_client.get(f"{A}/categories/"))
    kiyim = next(c for c in categories if c["slug"] == "kiyim")
    saved = ok(await admin_client.patch(f"{A}/categories/{kiyim['id']}/", json={"translations": {"en": {"name": "Clothes"}}}))
    cover = await catalog_image(admin_client, storage)
    tutorial = ok(await admin_client.post("/api/admin/tutorials/", json={
        "title": "Krujkaga rasm", "cover_media_id": cover, "is_published": True,
        "translations": {"ru": {"title": "Фото на кружку"}},
    }, headers=RU), 201)

    shelves = {c["slug"]: c["name"] for c in ok(await admin_client.get("/api/catalog/categories/?lang=en"))}
    public = ok(await admin_client.get("/api/tutorials/", headers=RU))

    assert saved["name"] == "Kiyim" and saved["translations"] == {"en": {"name": "Clothes"}}
    assert shelves["kiyim"] == "Clothes" and shelves["boshqa"] == "Boshqalar"
    assert tutorial["title"] == "Krujkaga rasm" and tutorial["translations"]["ru"]["title"] == "Фото на кружку"
    assert public[0]["title"] == "Фото на кружку"


@pytest.mark.asyncio
async def test_a_user_keeps_a_language(client: httpx.AsyncClient) -> None:
    registered = await client.post(
        "/api/auth/register/", headers=RU,
        json={"first_name": "Ivan", "email": "ivan@example.com", "password": "password123"},
    )
    assert registered.status_code == 200, registered.text
    assert registered.json()["user"]["language"] == "ru"

    changed = ok(await client.patch("/api/users/profile/me/", json={"language": "en"}))
    kept = ok(await client.patch("/api/users/profile/me/", json={"first_name": "Ivan", "language": None}))
    wrong = await client.patch("/api/users/profile/me/", json={"language": "de"})

    assert changed["language"] == kept["language"] == "en"
    assert ok(await client.get("/api/auth/me"))["language"] == "en"
    assert wrong.status_code == 422


@pytest.mark.asyncio
async def test_an_order_line_keeps_its_names_in_every_language(
    client: httpx.AsyncClient, storage: FakeStorage, session_factory: async_sessionmaker[AsyncSession]
) -> None:
    s = await shop(client, storage, session_factory)
    await as_admin(client)
    ok(await client.patch(f"{A}/products/{s['product']['id']}/", json={"translations": {"ru": {"name": "Кружка"}}}))
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"translations": VARIANT_TEXTS}))
    ok(await client.patch(f"{A}/colors/{s['black']}/", json={"translations": {"en": {"name": "Black"}}}))
    await set_sizes(client, s["variant_id"], [{"label": "Katta", "surcharge": "0", "is_available": True}])
    await as_customer(client)
    ok(await add_item(client, storage, s, size="Большой", expected="149000"), 201)

    cart = ok(await client.get("/api/cart/", headers=RU))
    checkout = ok(await client.post("/api/checkout/", json={"contact_name": "Test", "delivery_method": "PICKUP"}))
    # The catalog changes afterwards; the order does not.
    await as_admin(client)
    ok(await client.patch(f"{A}/variants/{s['variant_id']}/", json={"translations": {"ru": {"name": "Другое"}}}))
    await as_customer(client)
    ru = ok(await client.get(f"/api/orders/{checkout['order_id']}/", headers=RU))["items"][0]
    en = ok(await client.get(f"/api/orders/{checkout['order_id']}/?lang=en"))["items"][0]

    assert cart["items"][0]["product_name"] == "Кружка" and cart["items"][0]["size"] == "Большой"
    line = checkout["order"]["items"][0]
    assert (line["product_name"], line["variant_name"], line["color_name"], line["size"]) == (
        "Krujka", "Xameleon", "Qora", "Katta"
    )
    assert line["translations"] == {
        "ru": {"product_name": "Кружка", "variant_name": "Хамелеон", "size": "Большой"},
        "en": {"variant_name": "Chameleon", "color_name": "Black"},
    }
    assert (ru["product_name"], ru["variant_name"], ru["color_name"], ru["size"]) == ("Кружка", "Хамелеон", "Qora", "Большой")
    assert (en["product_name"], en["variant_name"], en["color_name"], en["size"]) == ("Krujka", "Chameleon", "Black", "Katta")

    # A completed order's piece shows in the gallery under its snapshot name.
    async with session_factory() as session:
        (await session.get(Order, checkout["order_id"])).status = "COMPLETED"
        await session.commit()
    [piece] = ok(await client.get("/api/gallery/", headers=RU))
    assert piece["product_name"] == "Кружка"
