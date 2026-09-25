from fastapi import APIRouter

from app.api.v1 import (
    admin_catalog,
    admin_gallery,
    admin_templates,
    auth,
    branches,
    cart,
    catalog,
    catalog_assets,
    checkout,
    dashboard,
    delivery,
    gallery,
    media,
    orders,
    payments,
    reviews,
    settings,
    studio,
    tutorials,
    users,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(catalog.router)
api_router.include_router(catalog_assets.public_router)
api_router.include_router(catalog_assets.admin_router)
api_router.include_router(studio.router)
api_router.include_router(cart.router)
api_router.include_router(orders.router)
api_router.include_router(checkout.router)
api_router.include_router(delivery.router)
api_router.include_router(payments.router)
api_router.include_router(dashboard.router)
api_router.include_router(settings.router)
api_router.include_router(branches.router)
api_router.include_router(gallery.router)
api_router.include_router(media.router)
api_router.include_router(admin_catalog.router)
api_router.include_router(admin_templates.router)
api_router.include_router(admin_gallery.router)
api_router.include_router(tutorials.router)
api_router.include_router(tutorials.admin_router)
api_router.include_router(reviews.router)
api_router.include_router(reviews.admin_router)
