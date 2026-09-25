# Dizzo Studio Monorepo

Yagona monorepo: Dizzo tizimining Backend, Frontend va Mobile loyihalari bir joyda jamlangan.

## Repozitoriy Tuzilishi

* **`Dizzo-Studio-Backend/`** — FastAPI / Python backend xizmati
* **`Dizzo-Studio-Frontend/`** — Next.js / React veb ilovasi
* **`Dizzo-Studio-Mobile/`** — Flutter mobil ilovasi
* **`.github/workflows/`** — Avtomatik sinxronizatsiya va CI/CD workflow'lari
* **`sync.sh`** — Mahalliy boshqaruv va tezkor sinxronizatsiya skripti

---

## Ikki Tomonlama Avtomatik Sinxronizatsiya (2-Way Auto-Sync)

Ushbu repozitoriy `dizzo-org` tashkiloti repozitoriyalari bilan to'liq sinxronlangan:

1. **Monorepodan tashkilot repolariga (Monorepo -> Standalone):**
   * Siz ushbu repozitoriyga (`main` branch) o'zgarishlarni push qilganingizda, GitHub Actions avtomatik ravishda:
     - `Dizzo-Studio-Backend` dagi o'zgarishlarni `dizzo-org/Dizzo-Studio-Backend` ga;
     - `Dizzo-Studio-Frontend` dagi o'zgarishlarni `dizzo-org/Dizzo-Studio-Frontend` ga;
     - `Dizzo-Studio-Mobile` dagi o'zgarishlarni `dizzo-org/Dizzo-Studio-Mobile` ga ajratib push qiladi.
   * `dizzo-org` ga o'zgarish yetib borgach, mavjud production deploy jarayonlari avtomatik ishga tushadi.

2. **Tashkilot repolaridan monorepoga (Standalone -> Monorepo):**
   * Agar jamoa a'zolari to'g'ridan-to'g'ri `dizzo-org` dagi alohida repolarga commit qilsa, ularning GitHub Action'lari avtomatik ravishda o'sha o'zgarishlarni ushbu monorepoga commit qilib qo'yadi.
   * Siz shunchaki `./sync.sh pull` yoki `git pull` qilib oxirgi o'zgarishlarni olasiz.

3. **Loop himoyasi:**
   * Sinxronizatsiya xabarlarida `[skip-sync]` tegidan foydalaniladi, bu esa cheksiz aylanma sinxronizatsiya (infinite loop) ning oldini oladi.

---

## Foydalanish Buyruqlari

Mahalliy terminalda qulay ishlash uchun `sync.sh` mavjud:

```bash
# Barcha o'zgarishlarni monorepoga push qilish
./sync.sh push "feat: yangi xususiyat qo'shildi"

# Tashkilotdagi eng so'nggi o'zgarishlarni monorepoga tortib olish
./sync.sh pull

# Holatni ko'rish
./sync.sh status
```
