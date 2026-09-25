"""Order messages sent to Telegram (app/services/telegram_notify.py), each in
its recipient's language. Telegram's HTML markup stays as it is."""

MESSAGES: dict[str, dict[str, str]] = {
    "🆕 <b>Yangi buyurtma #{number}</b>\nSumma: {amount} so'm\nBatafsil: {link}": {
        "ru": "🆕 <b>Новый заказ #{number}</b>\nСумма: {amount} сум\nПодробнее: {link}",
        "en": "🆕 <b>New order #{number}</b>\nTotal: {amount} UZS\nDetails: {link}",
    },
    "📦 <b>Buyurtma #{number}</b>\nHolati: {status}\nBatafsil: {link}": {
        "ru": "📦 <b>Заказ #{number}</b>\nСтатус: {status}\nПодробнее: {link}",
        "en": "📦 <b>Order #{number}</b>\nStatus: {status}\nDetails: {link}",
    },
}
