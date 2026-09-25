# Dizzo mobile: architecture

Dizzo's customer app (Flutter, Android + iOS, phones and tablets). It is not
a copy of the website. It shares the website's FastAPI backend
(`https://api.dizzo.uz/api`) and its data shapes.

**Product rules that apply to every screen**

- UI language: **Uzbek Latin**, written with the typographic apostrophe `‘`
  (`O‘zbek`, `so‘m`, `Ro‘yxatdan o‘tish`). Strings live inline in widgets;
  there is no l10n layer yet.
- **Titles and actions only.** Don't put explanatory text under titles, in
  dialogs, sheets or empty states. `EmptyState` has no description parameter
  on purpose.
- Screens must work at every width from a 320 px phone to a tablet (see
  [Responsive](#responsive)).
- Guests can browse. Anything that needs an account calls `ensureSignedIn`
  (see [Auth](#auth)).

---

## Folders

```
lib/
  main.dart                  ProviderScope(retry: providerRetry) + native splash hand-off
  app.dart                   MaterialApp.router, theme, locale, text-scale clamp
  core/                      shared by all features; imports no feature (except core/router)
    config/env.dart          --dart-define values (API_BASE_URL, Google client ids)
    network/
      api_client.dart        dioProvider, sessionEventsProvider
      auth_interceptor.dart  Bearer token, refresh on 401, kSkipAuth
      api_exception.dart     ApiException (Uzbek message, kind, fieldErrors)
      retry_policy.dart      Riverpod auto-retry for transient failures only
    storage/token_storage.dart  TokenStorage (secure) + MemoryTokenStorage (tests)
    router/
      routes.dart            every path + helpers (Routes.product(slug) ...)
      app_router.dart        routerProvider: GoRouter, redirects, the route table
      app_shell.dart         tab scaffold (NavigationBar / NavigationRail, cart badge)
    theme/
      app_colors.dart        BrandColors, DizzoColors (ThemeExtension), context.colors / context.text
      app_tokens.dart        Insets, Radii, Motion, Gap
      app_theme.dart         AppTheme.light / .dark (Material 3)
      responsive.dart        WindowSize, Breakpoints, ContentWidth, SliverPageBody
    utils/
      money.dart             Money (decimal strings), formatSum → "149 000 so‘m"
      json.dart              JsonRead extension for hand-written fromJson
    widgets/                 shared UI; import `core/widgets/widgets.dart` (barrel)
  features/<feature>/
    data/                    API classes + their providers (talk to dio)
    domain/                  immutable models (fromJson), sealed states
    presentation/            screens, feature widgets, controllers/providers
```

Features in place: `auth`, `home`, `catalog` (done); `cart` (badge provider
done, screen placeholder); `designs`, `editor`, `checkout`, `orders`,
`reviews`, `profile` (placeholders, see [Placeholders](#placeholders)).

**Rules**

- A feature may import `core/` and another feature's `domain/` or
  `presentation/` providers and widgets (e.g. `home` uses catalog providers and
  `product_grid.dart`). Never import another feature's private widgets
  (files starting with `_`, private classes).
- `core/` never imports features. The one exception is `core/router/`, the
  composition root: it builds the screens and the shell, which watches the
  cart badge.
- Relative imports inside `lib/`, `package:dizzo/...` in `test/`.
- Lints: `flutter_lints` plus the rules in `analysis_options.yaml`
  (strict casts, single quotes, `unawaited_futures`, `directives_ordering`).
  `flutter analyze` must stay clean.

## State (Riverpod 3, no code generation)

Plain providers only:

| Need | Use |
|---|---|
| a service/API object | `Provider<T>` |
| data loaded once and shared (products, categories) | `FutureProvider<T>` (kept alive) |
| data per argument (a product by slug) | `FutureProvider.autoDispose.family<T, Arg>` |
| a state machine with methods | `Notifier<T>` + `NotifierProvider` (`AuthController`, `CatalogFilterController`) |
| async state with mutations (cart, designs) | `AsyncNotifier<T>` + `AsyncNotifierProvider` |

- Don't use `StateProvider`/`ChangeNotifierProvider` (legacy in Riverpod 3).
- Screens are `ConsumerWidget` / `ConsumerStatefulWidget`. Short-lived
  UI state (a selected colour, a form) stays in `State`.
- Riverpod 3 retries failed providers automatically. `providerRetry`
  (in `main.dart`) retries only offline, timeout and 5xx errors, 3 times at
  most. A 404 or 422 fails straight away.
- To refresh after a mutation, call `ref.invalidate(provider)`. Pull-to-refresh
  invalidates the providers and awaits `ref.read(provider.future)`.
- Render async values with `.when(skipLoadingOnRefresh: true, ...)`. Show
  skeletons while loading and `ErrorState(error: e, onRetry: ...)` on error.

## Models

Models are written by hand, immutable, with a `factory X.fromJson(Json json)`
built on the `JsonRead` helpers (`json.str('name')`,
`json.list('items', Item.fromJson)`, `json.intOrNull(...)`). These helpers
tolerate missing or `null` fields, so a missing optional field doesn't crash a
screen. Add `toJson()` only when the model is sent back.

- **Money** comes as decimal strings (`"149000.00"`). Parse with
  `Money.parse(json['price'])`. `Money.raw` keeps the original string for
  requests, `Money.amount` is for display and on-screen maths, and
  `money.format()` gives `149 000 so‘m` with non-breaking spaces. Never
  compute prices the server owns (quotes come from `POST /catalog/quote/`).
- **Images** are absolute URLs. Show them with `AppImage(url)`.
- The catalog models mirror `Dizzo-Frontend/app/types/catalog.ts` and
  `Dizzo-Backend/app/schemas/catalog.py`. `ProductShape.raw` keeps the whole
  shape JSON (areas, anchors, model transform) for the editor.

## API client

`dioProvider` is the only HTTP client. Its base URL is `Env.apiBaseUrl`
(`.../api`). Paths start with `/` and keep the backend's trailing slash:

```dart
class OrdersApi {
  OrdersApi(this._dio);
  final Dio _dio;

  Future<List<OrderSummary>> list() async {
    try {
      final res = await _dio.get<Object?>('/orders/');
      return mapList(res.data, OrderSummary.fromJson);
    } catch (e) {
      throw ApiException.from(e);   // screens only ever see ApiException
    }
  }
}
final ordersApiProvider = Provider((ref) => OrdersApi(ref.watch(dioProvider)));
```

- **Auth header**: `AuthInterceptor` adds `Authorization: Bearer <access>`
  whenever tokens exist. For public calls that must never carry a token
  (login, register), pass `Options(extra: {kSkipAuth: true})`.
- **401 → refresh**: the interceptor calls `POST /auth/token/refresh/` with
  `{"refresh_token": ...}`, stores the new pair and replays the request once.
  Concurrent 401s share one refresh.
- **Refresh rejected (4xx)**: tokens are cleared and
  `sessionEventsProvider` emits `SessionEvent.expired`. `AuthController` then
  switches to `Guest`, and the router sends account-only pages to the welcome
  screen. If the refresh fails because the phone is offline or the server
  returns 5xx, the session stays.
- **Errors**: `ApiException.from(e)` gives `kind` (network, timeout,
  unauthorized, notFound, gone, conflict, validation, server...),
  `message` (Uzbek, taken from FastAPI's `detail` when present) and
  `fieldErrors` (422 `loc` → `msg`, for forms). Show it with
  `showAppSnack(context, e.message, error: true)` or `ErrorState(error: e)`.
- Tests replace the client:
  `dioProvider.overrideWithValue(fakeDio(routedAdapter({...})))`
  (see `test/helpers/fake_api.dart`).

## Auth

`authControllerProvider` (`features/auth/presentation/auth_controller.dart`)
holds a sealed `AuthState`:

- `AuthUnknown`: the app is starting and tokens are being read. The router
  shows the splash (brand loader).
- `Guest`: browsing without an account.
- `Authenticated(user)`: the user is signed in. The last `/auth/me` is cached
  in secure storage, so the app opens signed in even when offline. If tokens
  exist but no user is cached, the state holds `AppUser.pending` (id 0) until
  `/auth/me` answers.

```dart
final user = ref.watch(currentUserProvider);          // AppUser?
final auth = ref.read(authControllerProvider.notifier);
await auth.signInWithEmail(email, password);          // throws ApiException
await auth.register(firstName: ..., email: ..., password: ...);
await auth.signInWithGoogle();                        // false = user cancelled
await auth.completeSignIn(result);                    // any AuthResult (Telegram)
await auth.refreshUser();  await auth.updateUser(u);  await auth.logout();
```

**Gating an action** (add to cart, save a design, order):

```dart
if (!await ensureSignedIn(context, ref)) return;   // opens the login sheet if needed
await ref.read(cartProvider.notifier).add(...);    // continues after sign-in
```

`showLoginSheet(context)` opens the same sheet directly. `LoginPanel` is the
block with all sign-in methods. The welcome screen (`/welcome`) and the sheet
both use it.

**Methods**

| Method | Flow |
|---|---|
| Email | `POST /auth/login/` `{email, password}` / `POST /auth/register/` `{first_name, last_name, phone_number, email, password}`. Both return `{access_token, refresh_token, user}`. |
| Google | `google_sign_in` 7 (`GoogleAuth`). `authenticate()` returns an `idToken`, which is sent to `POST /auth/oauth/google/` as `{"id_token"}`. |
| Telegram | Native "Log in with Telegram" (`TelegramNativeLogin`, channel `uz.dizzo/telegram_login`, implemented by `TelegramLoginPlugin` in `android/app/src/main/kotlin/uz/dizzo/studio/` and `ios/Runner/`). The official SDK opens Telegram, or its own browser sheet when Telegram isn't installed, and returns an OIDC `id_token`, which is sent to `POST /auth/oauth/telegram-oidc/` as `{"id_token"}`. `TelegramLoginSheet` shows "Telegramda tasdiqlang" with "Qayta ochish" / "Bekor qilish", and "Telegram orqali kirib bo‘lmadi" + "Qayta urinish" on any failure. The app has no bot deep-link login. |
| Logout | `POST /auth/logout/` `{"refresh_token"}`, then the app clears its tokens and signs out of Google. |

**Configuration** (`lib/core/config/env.dart`, values in `config/prod.json`):

| Define | Value | Used for |
|---|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | web client id `859762564989-9clc….apps.googleusercontent.com` (= backend `GOOGLE_CLIENT_ID`) | `serverClientId`: the id token's audience |
| `GOOGLE_IOS_CLIENT_ID` | iOS client `859762564989-g7kn….apps.googleusercontent.com` | iOS `clientId`, `GIDClientID` and the reversed-id URL scheme |
| `TELEGRAM_CLIENT_ID` | `8249953132` (= backend `TELEGRAM_OIDC_CLIENT_ID`) | SDK `clientId` |
| `TELEGRAM_REDIRECT_URI` | `https://app2398820989-login.tg.dev/tglogin` | Android SDK redirect + App Link intent filter |
| `TELEGRAM_IOS_REDIRECT_URI` | empty → the origin of `TELEGRAM_REDIRECT_URI` | iOS SDK redirect + Associated Domain |

- Google: the Android OAuth client (`uz.dizzo.studio`) must list the SHA-1 of
  every signing key: debug, upload and Play App Signing
  (`cd android && ./gradlew signingReport`, Play Console → App integrity).
  The Google button is hidden until the ids for the platform are set
  (`GoogleAuth.isAvailable`). `googleSignInError` maps failures to Uzbek
  messages (cancel → nothing, offline, not configured, no Google account).
- Google on iOS: the URL scheme in `Info.plist` is `$(GOOGLE_REVERSED_CLIENT_ID)`.
  The scheme pre-action `ios/scripts/dart_defines_to_xcconfig.sh` writes it
  (and `TELEGRAM_LOGIN_HOST`) from the dart-defines into
  `ios/Flutter/DartDefines.xcconfig` (ignored by git). The defaults (the
  same ids as `config/prod.json`) are in `ios/Flutter/Debug.xcconfig` /
  `Release.xcconfig`; keep them in sync with `env.dart`.
- Telegram (@BotFather → Bot Settings → Login Widget): the Android app is
  registered with package `uz.dizzo.studio` and the **SHA-256** of every
  signing key (debug, upload, Play App Signing); the App Link
  (`android:autoVerify`) only verifies for those keys. The iOS app needs its
  bundle id `uz.dizzo.studio` + Apple Team ID registered there, and the App
  ID needs the Associated Domains capability (`Runner.entitlements`:
  `applinks:$(TELEGRAM_LOGIN_HOST)`).
- Android SDK source: `org.telegram:login-sdk` is only on GitHub Packages,
  which needs a GitHub token, so the build compiles the identical,
  MIT-licensed 1.0.0 sources in `android/app/src/telegramLoginSdk/`.
  `DIZZO_TELEGRAM_SDK=maven` (env or Gradle property, plus
  `gpr.user`/`gpr.key` or `GITHUB_USERNAME`/`GITHUB_TOKEN`) uses the artifact
  instead. iOS uses the Swift package
  `https://github.com/TelegramMessenger/telegram-login-ios` (1.0.0, added to
  `Runner.xcodeproj`).

**Build config**

```
flutter run --dart-define-from-file=config/prod.json   # or a git-ignored copy: config/dev.json
```

Release builds: see the README.

## Routing (go_router)

All paths are in `core/router/routes.dart`. Navigate with the helpers, never
with string literals:

| Path | Screen | Notes |
|---|---|---|
| `/splash` | `BrandLoaderScreen` | shown until the auth state and the welcome flag are known |
| `/welcome?from=` | `WelcomeScreen` | first launch + where guests are sent from account-only pages |
| `/` | `HomeScreen` | tab "Asosiy" |
| `/products` | `CatalogScreen` | tab "Mahsulotlar" |
| `/designs` | `DesignsScreen` | tab "Dizaynlarim" (placeholder) |
| `/cart` | `CartScreen` | tab "Savat" (placeholder), badge = `cartCountProvider` |
| `/profile` | `ProfileScreen` | tab "Profil" (minimal) |
| `/product/:slug?variant=&color=&size=` | `ProductScreen` | `Routes.product(slug, query:)`; `extra`: hero tag (String). The page writes the choice into its query (`GoRouter.replace`, no transition) |
| `/editor/:slug?variant=&color=&size=&design=` | `EditorScreen` | placeholder, `Routes.editor(slug, variant:, color:, size:)` |
| `/checkout` | `CheckoutScreen` | account only |
| `/orders`, `/orders/:id` | `OrdersScreen`, `OrderDetailScreen` | account only |
| `/reviews` | `MyReviewsScreen` ("Fikrlarim") | account only |

- Tabs use `StatefulShellRoute.indexedStack`, so each tab keeps its own
  stack. Tapping the current tab again returns to the tab's first page. Use
  `context.go(Routes.products)` to switch tabs and `context.push(...)` for
  full-screen pages (they sit above the tab bar).
- Account-only paths are listed in `Routes.requiresAuth`. The redirect sends
  guests to `/welcome?from=<path>` and back to that path after sign-in.
  Prefer `ensureSignedIn` for actions; the redirect is a safety net.

**Adding a screen**

1. Create `lib/features/<feature>/presentation/<name>_screen.dart`.
2. Add the path (and a helper if it has parameters) to `Routes`, and add it to
   `requiresAuth` if it needs an account.
3. Register a `GoRoute` in `app_router.dart`. A top-level route opens full
   screen; a route inside a `StatefulShellBranch` keeps the tab bar.
4. Build the screen from `Scaffold` + `AppBar(title: Text('...'))`.
   Scrolling content uses `CustomScrollView` + `SliverPageBody`, or
   `ListView` with `padding: EdgeInsets.symmetric(horizontal: context.pagePadding)`
   wrapped in `ContentWidth` on tablets.
5. Put data access in `data/` (API class + provider) and models in
   `domain/`, then add a test.

## Design system

**Brand**: primary orange `#ED5124` (`BrandColors.orange`), accent
`#F99517` (`BrandColors.amber`), ink `#111827`. Filled buttons with white
text use `brandStrong` (`#D24419`), which passes AA contrast. Font: **Plus
Jakarta Sans** (bundled, weights 400–800, family `PlusJakartaSans`).

**Tokens** (read through `context.colors` → `DizzoColors`; light and dark are
both defined, and the app runs light for now):

| Token | Light | Use |
|---|---|---|
| `brand` | `#ED5124` | accents, icons, badges, prices |
| `brandStrong` | `#D24419` | filled buttons (`ColorScheme.primary`) |
| `accent` | `#F99517` | secondary highlights |
| `ink` / `inkMuted` / `inkSubtle` | `#111827` / `#4B5563` / `#9CA3AF` | text |
| `background` | `#FBF9F8` | scaffold |
| `surface` | `#FFFFFF` | cards, sheets, bars |
| `plate` | `#F3EEE9` | warm plate behind product pictures |
| `line` | `#EBE3DC` | borders, dividers |
| `success` / `warning` / `danger` | | statuses |

- Text: `context.text.headlineSmall`, etc. The weights and letter-spacing are
  tuned in `AppTheme._textTheme`.
- Spacing: `Insets.xs/sm/md/lg/xl/xxl` (4/8/12/16/24/32) and `Gap.md`, etc.
- Radii: `Radii.brMd` (12, inputs and buttons), `brLg` (16, cards and
  images), `brXl` (24, sheets and hero).
- Motion: `Motion.fast/normal/slow`. Every option picker gives light haptic
  feedback.
- Smoothness: put a `RepaintBoundary` around anything that animates on its
  own; drive small animated parts (page dots, a clear button) with a
  `ValueListenableBuilder` instead of `setState` on the whole screen; watch
  providers with `.select(...)` when a screen needs one field.
- Material 3 components are themed centrally (buttons, inputs, chips,
  sheets, navigation), so use the stock widgets without per-widget styling.

## Responsive

`context.windowSize` returns `compact` (<600), `medium` (600–839) or
`expanded` (≥840). Helpers: `context.isCompact`, `context.pagePadding`
(12 below 360 px, 16 on phones, 24 on tablets).

- The shell uses a bottom `NavigationBar` on compact screens and a
  `NavigationRail` from medium up.
- Content is capped at `Breakpoints.contentMaxWidth` (1100) with
  `ContentWidth` / `SliverPageBody`. Forms and sheets are capped at
  `formMaxWidth` (480) / 560.
- Product grids have 2 to 5 columns (`ResponsiveContext.productColumnsFor`).
  Tile heights are computed from the user's text scale, so don't hard-code
  heights that contain text.
- The text scale is clamped to 0.9–1.35 in `app.dart`.
- `ProductScreen` shows a collapsing gallery on phones and two columns on
  tablets. Follow this pattern for detail screens.

**Product page** (`features/catalog/presentation/product_screen.dart`)

- The choice is a `ProductSelection` (`domain/product_selection.dart`): type
  and colour default to the first ones, a size is never pre-selected (as on
  the web). It is read from the route query, else from
  `productChoiceMemoryProvider` (last choice per product this session), and
  written back to both.
- Pictures: `picturesFor(product, variant, color)`: the colour's photos, else
  the type's, else the product's (cover first). Never mixed.
  `ImageGallery` cross-fades between sets, keeps the page index when the new
  set is long enough, and precaches the first pictures of
  `likelyNextPictures` (at most 6).
- Price: the product's "from" price until a choice is made, then
  `productQuoteProvider` (`POST /catalog/quote/`, debounced) with the local
  sum shown until it answers.
- 3D: `Product3dScreen` creates its own `WebDesignEngine` only when opened and
  disposes it on close.

## Shared widgets (`core/widgets/widgets.dart`)

| Widget | Purpose |
|---|---|
| `AppButton(label, onPressed, icon:, variant:, loading:, expand:)` | primary / secondary (ink) / outline / ghost; full width by default; built-in spinner |
| `CircleIconButton` | round button over images |
| `ProductCard(name, imageUrl, price, fromPrice:, badge:, onTap:, heroTag:)` | grid tile (takes plain values) |
| `PriceText(money, from:, style:)` | "149 000 so‘m" (+ "dan") with a smaller currency |
| `AppImage(url, fit:, borderRadius:, cacheWidth:)` | cached network image, shimmer placeholder, fallback icon; decodes at a bucketed width (`AppImage.decodeWidth`), `AppImage.precache(...)` warms it. Wrap it in `Hero(flightShuttleBuilder: appImageFlightShuttle)` |
| `Skeleton`, `Skeleton.line`, `SkeletonScope`, `ProductCardSkeleton` | shimmer loaders (wrap groups in one `SkeletonScope`) |
| `EmptyState(title, icon:, actionLabel:, onAction:, compact:)` | title + one action only |
| `ErrorState(error, onRetry:)` | uses `ApiException.message`, "Qayta urinish" |
| `showAppSnack(context, msg, error:)` | floating snackbar |
| `showAppBottomSheet(context, title:, builder:)`, `AppSheet` | rounded sheet with a title and close button, keyboard-safe |
| `confirmSheet(context, title:, confirmLabel:, destructive:)` | yes/no question → `bool` |
| `SectionHeader(title, actionLabel:, onAction:)` | section title + "Barchasi" |
| `BrandLoader(size:)`, `BrandLoaderScreen` | the animated logo (port of the site's `BrandLoader.vue`); use it for full-screen loads, and use skeletons for content |
| `PlaceholderScreen(title:)` | "Tez orada" stand-in |
| `ContentWidth`, `SliverPageBody` | width cap + page padding |

Catalog widgets you can reuse from other features:
`features/catalog/presentation/widgets/`: `SliverProductGrid`,
`CategoryChips`, `CategoryTile`, `ColorPicker`, `SizePicker`,
`VariantPicker`, `MethodBadge`, `SpecsTable`, `ImageGallery`, `ImageViewer`,
`VariantCards`, `ColorSwatches`, `CollapsibleDescription`. The editor uses
`VariantPicker` / `ColorPicker` / `SizePicker`; the product page uses the
card and swatch versions.

## Providers you can reuse

| Provider | Value |
|---|---|
| `authControllerProvider`, `currentUserProvider` | session |
| `productsProvider`, `popularProductsProvider`, `categoriesProvider` | catalog lists |
| `productDetailProvider(slug)` | `ProductDetail` (cached for 5 min) |
| `productQuoteProvider((variantId, colorId, size))` | server price of a choice (`Money`) |
| `productChoiceMemoryProvider` | last product-page choice per slug |
| `catalogFilterProvider` | catalog search + category (home sets the category) |
| `galleryProvider` | customer works |
| `cartSummaryProvider` / `cartCountProvider` | tab badge; **invalidate `cartSummaryProvider` after every cart change**, or give it your cart state's count (keep the names) |
| `dioProvider`, `tokenStorageProvider`, `sessionEventsProvider` | infrastructure |

## Placeholders

These screens exist with their final routes and constructor parameters.
Replace their bodies:

- `features/editor/presentation/editor_screen.dart`: `EditorScreen(slug, variantId, colorId, size, designId)`
- `features/designs/presentation/designs_screen.dart`: tab; shows "Kirish" to guests
- `features/cart/presentation/cart_screen.dart`: tab; shows "Kirish" to guests
- `features/checkout/presentation/checkout_screen.dart`
- `features/orders/presentation/orders_screen.dart`, `order_detail_screen.dart` (`orderId` String)
- `features/reviews/presentation/my_reviews_screen.dart`
- `features/profile/presentation/profile_screen.dart`: minimal (user, Buyurtmalar, Fikrlarim, Chiqish); extend it

## Backend endpoints used so far

| Endpoint | Where |
|---|---|
| `POST /auth/login/`, `POST /auth/register/` | `AuthApi` |
| `POST /auth/token/refresh/` `{refresh_token}` | `AuthInterceptor` |
| `POST /auth/oauth/google/` `{id_token}` | `AuthApi.google` |
| `POST /auth/oauth/telegram-oidc/` `{id_token}` | `AuthApi.telegramOidc` |
| `GET /auth/me` | `AuthController.refreshUser` |
| `POST /auth/logout/` `{refresh_token}` | `AuthApi.logout` |
| `GET /catalog/products/` (`?sort=popular`) | `CatalogApi.products` |
| `GET /catalog/categories/` | `CatalogApi.categories` |
| `GET /catalog/products/{slug}/` | `CatalogApi.product` |
| `POST /catalog/quote/` `{variant_id, color_id, quantity, size}` | `CatalogApi.quote` |
| `GET /gallery/?limit=12` | `galleryProvider` |
| `GET /cart/` (`total_items`) | `cartSummaryProvider` |

## Platform

- Android: `applicationId uz.dizzo.studio`, minSdk 23 (secure storage,
  Credential Manager and the Telegram SDK need it). The manifest declares
  INTERNET, `<queries>` for `tg:`/`https:`/Telegram packages/Custom Tabs, and
  `TelegramLoginCallbackActivity` with the Telegram App Link. versionName /
  versionCode come from `pubspec.yaml` (`version: name+code`).
- Android release: signed with the upload key from `android/key.properties`
  or the file `DIZZO_KEY_PROPERTIES` points to (`storePassword`,
  `keyPassword`, `keyAlias`, `storeFile`). Without either, Gradle warns and
  signs with the debug key. Neither file nor any `*.jks` is committed.
  R8 minify and resource shrinking are on; keep rules are in
  `android/app/proguard-rules.pro`.
- iOS: bundle id `uz.dizzo.studio`, display name Dizzo, deployment target
  15.0 (Telegram SDK), `LSApplicationQueriesSchemes` = `tg`, `https`, the
  Google URL scheme, Associated Domains (`Runner/Runner.entitlements`) and a
  privacy manifest (`Runner/PrivacyInfo.xcprivacy`). It declares no
  tracking. Collected data, all for app functionality: name, email, phone,
  user id, address, precise location, photos, user content and purchases.
  Required-reason APIs: file timestamps C617.1, user defaults CA92.1 and
  system boot time 35F9.1. Plugins ship their own manifests. If CocoaPods is
  used, set `platform :ios, '15.0'` in the generated `ios/Podfile`.
- App icon: `dart run flutter_launcher_icons`. Splash:
  `dart run flutter_native_splash:create`. Both read their sources from
  `assets/launcher/` (generated from `assets/brand/dizzo-mark.png`). The native
  splash stays up until the first Flutter frame, then the brand loader shows
  while the session is restored.

## Checks

On this development machine drive C: is nearly full. Keep every cache on D:
for **all** flutter/dart/gradle commands:

```
export GRADLE_USER_HOME='D:\gradle-home' PUB_CACHE='D:\pub-cache'   # bash
$env:GRADLE_USER_HOME='D:\gradle-home'; $env:PUB_CACHE='D:\pub-cache'  # PowerShell
```

```
flutter analyze        # must be clean
flutter test           # unit + widget + app-flow tests (fake backend)
flutter build apk --debug
```
