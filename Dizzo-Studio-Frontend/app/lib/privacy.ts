// The privacy policy (/privacy), in the three languages. Keep the three in
// step and move UPDATED when the text changes. Section ids are anchors
// (#delete-account is linked from the profile and the stores).

export const PRIVACY_UPDATED = '2026-09-17';

export interface PrivacySection { id: string; title: string; paragraphs?: string[]; items?: string[] }
export interface PrivacyText { title: string; intro: string; updated: string; sections: PrivacySection[] }

const uz: PrivacyText = {
  title: 'Maxfiylik siyosati',
  updated: 'Oxirgi yangilanish',
  intro: 'Dizzo (dizzo.uz sayti, Dizzo ilovasi va @dizzo_uz Telegram boti) sizning ma’lumotlaringizni faqat buyurtmangizni tayyorlash va xizmatni yaxshilash uchun ishlatadi. Quyida nimani, nima uchun yig‘ishimiz va ularni qanday boshqarishingiz mumkinligini oddiy tilda tushuntiramiz.',
  sections: [
    {
      id: 'data',
      title: 'Qanday ma’lumotlarni yig‘amiz',
      items: [
        'Hisob: ism, familiya, email, telefon raqami, profil rasmi; Google yoki Telegram orqali kirsangiz — o‘sha xizmat bergan identifikator va ism.',
        'Buyurtmalar: yetkazib berish manzili, qabul qiluvchi ismi va telefoni, buyurtma tarkibi va holati.',
        'Dizaynlar: siz yuklagan rasmlar, yozgan matnlar va Studio’da yaratgan dizaynlaringiz.',
        'Fikrlar: siz qoldirgan sharh, baho va rasmlar.',
        'Texnik ma’lumotlar: IP manzil, brauzer yoki qurilma turi, tanlangan til, xatolik va so‘rovlar jurnali; saytda kirishni saqlab turish uchun cookie fayllari.',
      ],
    },
    {
      id: 'use',
      title: 'Ma’lumotlardan nima uchun foydalanamiz',
      items: [
        'Buyurtmani qabul qilish, tayyorlash, yetkazish va siz bilan bog‘lanish.',
        'Hisobingizga kirish, dizayn va savatingizni saqlash.',
        'Buyurtma holati haqida Telegram orqali xabar yuborish (agar hisobingiz bog‘langan bo‘lsa).',
        'Firibgarlik va suiiste’molning oldini olish, xatolarni tuzatish va xizmatni yaxshilash.',
      ],
      paragraphs: ['Ma’lumotlaringizni sotmaymiz va reklama uchun uchinchi shaxslarga bermaymiz.'],
    },
    {
      id: 'sharing',
      title: 'Kimlar bilan bo‘lishamiz',
      items: [
        'Yetkazib berish xizmati — faqat buyurtmani yetkazish uchun kerakli manzil, ism va telefon.',
        'Infratuzilma provayderlari: sayt va fayllar Cloudflare’da, ma’lumotlar bazasi bizning serverimizda saqlanadi.',
        'Google va Telegram — faqat siz ular orqali kirishni tanlasangiz.',
        'Qonun talab qilganda — vakolatli davlat organlariga.',
      ],
    },
    {
      id: 'storage',
      title: 'Qancha vaqt saqlaymiz',
      paragraphs: [
        'Hisob ma’lumotlari hisobingiz faol bo‘lguncha saqlanadi. Mehmon sifatida yuklangan rasmlar, agar hisobga biriktirilmasa, avtomatik o‘chiriladi. Yakunlangan buyurtmalar hisob-kitob va qonuniy talablar uchun saqlanadi. Ma’lumotlar xavfsiz ulanish (HTTPS) orqali uzatiladi, parollar faqat shifrlangan ko‘rinishda saqlanadi.',
      ],
    },
    {
      id: 'rights',
      title: 'Sizning huquqlaringiz',
      items: [
        'Profil sahifasida ma’lumotlaringizni ko‘rish va o‘zgartirish.',
        'Saytda, ilovada va Telegram xabarlarida tilni tanlash.',
        'Hisobingizni va unga bog‘liq ma’lumotlarni o‘chirish (pastda).',
        'Savol yoki shikoyat bilan bizga murojaat qilish.',
      ],
    },
    {
      id: 'delete-account',
      title: 'Hisobni o‘chirish',
      paragraphs: [
        'Hisobingizni istalgan vaqtda o‘zingiz o‘chirishingiz mumkin:',
      ],
      items: [
        'Saytda: Profil → “Hisobni o‘chirish”.',
        'Ilovada: Profil → “Hisobni o‘chirish”.',
        'Yoki Telegram’da @dizzo_uz ga yozing — so‘rovingizni 30 kun ichida bajaramiz.',
        'O‘chirilganda hisob, ism, email, telefon, kirish usullari, saqlangan dizaynlar va savat o‘chiriladi; sharhlaringiz ismsiz qoladi.',
        'Yakunlangan buyurtmalar hisob-kitob uchun saqlanadi, lekin hisobingizga bog‘lanmaydi. Yakunlanmagan buyurtma bo‘lsa, avval u yakunlanishi yoki bekor qilinishi kerak.',
      ],
    },
    {
      id: 'children',
      title: 'Bolalar',
      paragraphs: ['Xizmat 16 yoshdan kichik bolalarga mo‘ljallanmagan. Bola ma’lumoti bizga ota-onasining roziligisiz tushganini bilsangiz, bizga yozing — o‘chiramiz.'],
    },
    {
      id: 'changes',
      title: 'O‘zgarishlar va aloqa',
      paragraphs: [
        'Siyosat o‘zgarsa, shu sahifada yangi sana bilan e’lon qilamiz. Savollar bo‘yicha: Telegram @dizzo_uz, manzil: Toshkent shahri, Yunusobod tumani.',
      ],
    },
  ],
};

const ru: PrivacyText = {
  title: 'Политика конфиденциальности',
  updated: 'Последнее обновление',
  intro: 'Dizzo (сайт dizzo.uz, приложение Dizzo и Telegram-бот @dizzo_uz) использует ваши данные только для выполнения заказа и улучшения сервиса. Ниже простыми словами — какие данные мы собираем, зачем и как вы можете ими управлять.',
  sections: [
    {
      id: 'data',
      title: 'Какие данные мы собираем',
      items: [
        'Аккаунт: имя, фамилия, email, телефон, фото профиля; при входе через Google или Telegram — идентификатор и имя, которые передаёт этот сервис.',
        'Заказы: адрес доставки, имя и телефон получателя, состав и статус заказа.',
        'Дизайны: загруженные вами изображения, тексты и дизайны, созданные в Studio.',
        'Отзывы: ваш отзыв, оценка и фотографии.',
        'Технические данные: IP-адрес, тип браузера или устройства, выбранный язык, журналы ошибок и запросов; cookie для сохранения входа на сайте.',
      ],
    },
    {
      id: 'use',
      title: 'Зачем мы используем данные',
      items: [
        'Принять, изготовить и доставить заказ, а также связаться с вами.',
        'Обеспечить вход в аккаунт и сохранить ваши дизайны и корзину.',
        'Сообщать о статусе заказа в Telegram (если аккаунт привязан).',
        'Предотвращать мошенничество и злоупотребления, исправлять ошибки и улучшать сервис.',
      ],
      paragraphs: ['Мы не продаём ваши данные и не передаём их третьим лицам для рекламы.'],
    },
    {
      id: 'sharing',
      title: 'Кому мы передаём данные',
      items: [
        'Службе доставки — только адрес, имя и телефон, нужные для доставки.',
        'Поставщикам инфраструктуры: сайт и файлы размещены в Cloudflare, база данных — на нашем сервере.',
        'Google и Telegram — только если вы выбрали вход через них.',
        'Государственным органам — когда этого требует закон.',
      ],
    },
    {
      id: 'storage',
      title: 'Сколько мы храним данные',
      paragraphs: [
        'Данные аккаунта хранятся, пока аккаунт активен. Фото, загруженные гостем и не привязанные к аккаунту, удаляются автоматически. Завершённые заказы хранятся для учёта и требований закона. Данные передаются по защищённому соединению (HTTPS), пароли хранятся только в зашифрованном виде.',
      ],
    },
    {
      id: 'rights',
      title: 'Ваши права',
      items: [
        'Просматривать и изменять данные на странице профиля.',
        'Выбирать язык сайта, приложения и сообщений в Telegram.',
        'Удалить аккаунт и связанные с ним данные (ниже).',
        'Обратиться к нам с вопросом или жалобой.',
      ],
    },
    {
      id: 'delete-account',
      title: 'Удаление аккаунта',
      paragraphs: ['Вы можете удалить аккаунт в любое время самостоятельно:'],
      items: [
        'На сайте: Профиль → «Удалить аккаунт».',
        'В приложении: Профиль → «Удалить аккаунт».',
        'Или напишите нам в Telegram @dizzo_uz — мы выполним запрос в течение 30 дней.',
        'При удалении стираются аккаунт, имя, email, телефон, способы входа, сохранённые дизайны и корзина; отзывы остаются без имени.',
        'Завершённые заказы сохраняются для учёта, но больше не связаны с вами. Если есть незавершённый заказ, его нужно сначала завершить или отменить.',
      ],
    },
    {
      id: 'children',
      title: 'Дети',
      paragraphs: ['Сервис не предназначен для детей младше 16 лет. Если вы узнали, что к нам попали данные ребёнка без согласия родителей, напишите нам — мы их удалим.'],
    },
    {
      id: 'changes',
      title: 'Изменения и контакты',
      paragraphs: [
        'Если политика изменится, мы опубликуем её на этой странице с новой датой. По вопросам: Telegram @dizzo_uz, адрес: г. Ташкент, Юнусабадский район.',
      ],
    },
  ],
};

const en: PrivacyText = {
  title: 'Privacy policy',
  updated: 'Last updated',
  intro: 'Dizzo (the dizzo.uz website, the Dizzo app and the @dizzo_uz Telegram bot) uses your data only to make your order and improve the service. Here is, in plain words, what we collect, why, and how you control it.',
  sections: [
    {
      id: 'data',
      title: 'What we collect',
      items: [
        'Account: first and last name, email, phone number, profile picture; if you sign in with Google or Telegram, the identifier and name that service provides.',
        'Orders: delivery address, the recipient’s name and phone, what was ordered and its status.',
        'Designs: the images you upload, the text you write and the designs you make in the Studio.',
        'Reviews: your review, rating and photos.',
        'Technical data: IP address, browser or device type, chosen language, error and request logs; cookies that keep you signed in on the website.',
      ],
    },
    {
      id: 'use',
      title: 'Why we use it',
      items: [
        'To take, make and deliver your order, and to contact you about it.',
        'To sign you in and keep your designs and cart.',
        'To send order updates on Telegram (if your account is linked).',
        'To prevent fraud and abuse, fix errors and improve the service.',
      ],
      paragraphs: ['We don’t sell your data or share it with third parties for advertising.'],
    },
    {
      id: 'sharing',
      title: 'Who we share it with',
      items: [
        'The delivery service — only the address, name and phone needed to deliver.',
        'Infrastructure providers: the website and files are hosted on Cloudflare, the database on our own server.',
        'Google and Telegram — only if you choose to sign in with them.',
        'Public authorities — when the law requires it.',
      ],
    },
    {
      id: 'storage',
      title: 'How long we keep it',
      paragraphs: [
        'Account data is kept while your account is active. Images uploaded as a guest and never attached to an account are deleted automatically. Completed orders are kept for accounting and legal requirements. Data travels over secure connections (HTTPS), and passwords are stored only in hashed form.',
      ],
    },
    {
      id: 'rights',
      title: 'Your rights',
      items: [
        'See and change your data on the profile page.',
        'Choose the language of the website, the app and Telegram messages.',
        'Delete your account and the data tied to it (below).',
        'Contact us with a question or complaint.',
      ],
    },
    {
      id: 'delete-account',
      title: 'Deleting your account',
      paragraphs: ['You can delete your account yourself at any time:'],
      items: [
        'On the website: Profile → “Delete account”.',
        'In the app: Profile → “Delete account”.',
        'Or message us on Telegram at @dizzo_uz — we’ll complete the request within 30 days.',
        'Deleting removes the account, name, email, phone, sign-in methods, saved designs and cart; your reviews stay without your name.',
        'Completed orders are kept for our records but are no longer linked to you. If an order is still in progress, it has to be completed or cancelled first.',
      ],
    },
    {
      id: 'children',
      title: 'Children',
      paragraphs: ['The service isn’t meant for children under 16. If you learn that a child’s data reached us without a parent’s consent, write to us and we’ll delete it.'],
    },
    {
      id: 'changes',
      title: 'Changes and contact',
      paragraphs: [
        'If this policy changes, we’ll publish the new version here with a new date. Questions: Telegram @dizzo_uz, address: Yunusobod district, Tashkent.',
      ],
    },
  ],
};

export const PRIVACY: Record<'uz' | 'ru' | 'en', PrivacyText> = { uz, ru, en };
