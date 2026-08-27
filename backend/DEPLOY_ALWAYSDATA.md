# نشر AnimeWatcher API على Alwaysdata

دليل خطوة بخطوة لرفع الباك-إند (PHP + MySQL) على استضافة **Alwaysdata** المجانية.
Alwaysdata تسمح بطلبات cURL الخارجية، لذا سيعمل بروكسي Jikan والـ Scraper بالكامل.

> يفترض هذا الدليل أنك أنشأت الحساب وقاعدة البيانات `animewatcher_db` بالفعل
> (كما في لوحة التحكم: Databases → MySQL). المستخدم `animewatcher` يملك
> صلاحيات `all rights` على القاعدة.

---

## 1) بيانات قاعدة البيانات

على Alwaysdata لا يكون الـ host هو `127.0.0.1`. جهّز القيم التالية:

| المفتاح   | القيمة على Alwaysdata                          |
| --------- | ---------------------------------------------- |
| `DB_HOST` | `mysql-<حسابك>.alwaysdata.net`                 |
| `DB_PORT` | `3306`                                          |
| `DB_NAME` | `animewatcher_db`                               |
| `DB_USER` | `animewatcher` (أو `<حسابك>_animewatcher`)      |
| `DB_PASS` | كلمة مرور مستخدم قاعدة البيانات                  |

> اسم الـ host الدقيق يظهر في **Databases → MySQL** أعلى الصفحة
> (مثال: `mysql-animewatcher.alwaysdata.net`).

---

## 2) استيراد الجداول

استخدم الملف الجاهز **`backend/deploy/schema.import.sql`** (يحتوي الجداول فقط
بدون `CREATE DATABASE`، لأن القاعدة منشأة مسبقًا).

**عبر phpMyAdmin** (أيقونة PMA في لوحة alwaysdata):
1. اختر قاعدة `animewatcher_db` من القائمة اليسرى.
2. تبويب **Import** → اختر الملف `schema.import.sql` → **Go**.
3. تأكد من ظهور الجداول: `users`، `favorites`، `watch_history`.

**أو عبر SSH:**
```bash
mysql -h mysql-<حسابك>.alwaysdata.net -u animewatcher -p animewatcher_db \
  < backend/deploy/schema.import.sql
```

> لا تستخدم `backend/schema.sql` هنا لأنه يحتوي `CREATE DATABASE`/`USE`
> اللذين يفشلان على الاستضافة المشتركة.

---

## 3) رفع ملفات الكود

الطريقة الأسهل هي **Git** من داخل SSH الخاص بـ alwaysdata:

1. فعّل SSH: **Remote access → SSH** (استخدم نفس مستخدم الحساب).
2. ادخل عبر SSH وانسخ المستودع داخل مجلد الويب (عادةً `~/www/`):
   ```bash
   cd ~/www
   git clone https://github.com/MohammedEmad333/AnimeWatcher.git
   ```
   الباك-إند يصبح في `~/www/AnimeWatcher/backend`.

> بديل بدون Git: ارفع محتويات مجلد `backend/` عبر **SFTP** إلى مجلد
> داخل `~/www/`.

---

## 4) إنشاء ملف `.env`

في مجلد `backend/` أنشئ ملف `.env` (لا يُرفع إلى Git):
```bash
cd ~/www/AnimeWatcher/backend
cp .env.example .env
nano .env
```
واملأه بقيم alwaysdata:
```env
DB_HOST=mysql-<حسابك>.alwaysdata.net
DB_PORT=3306
DB_NAME=animewatcher_db
DB_USER=animewatcher
DB_PASS=كلمة-المرور

# ولّد سرًّا قويًّا:  openssl rand -hex 32
JWT_SECRET=<64-hex-عشوائي>
JWT_ISSUER=animewatcher.api
JWT_TTL=604800

# ضع نطاق تطبيقك بدل * في الإنتاج
CORS_ALLOWED_ORIGINS=*

JIKAN_BASE_URL=https://api.jikan.moe/v4
CACHE_TTL=21600
```
ولّد السر:
```bash
openssl rand -hex 32
```
تأكد أن مجلد `cache/` قابل للكتابة (ينشأ تلقائيًا، لكن للتأكد):
```bash
mkdir -p cache && chmod 775 cache
```

---

## 5) ضبط الموقع (Web → Sites)

في لوحة alwaysdata: **Web → Sites → Add a site**:

- **Type:** `PHP` (أباتشي مع PHP 8.1+).
- **Addresses:** نطاقك (مثل `<حسابك>.alwaysdata.net`).
- **Document root / Root directory:**
  `www/AnimeWatcher/backend`
  > مهم: اجعل جذر الموقع هو مجلد **`backend`** نفسه، حتى يعمل ملف
  > `.htaccess` والـ front controller والروابط النظيفة `/api/*`.
- **PHP version:** 8.1 أو أحدث.

`.htaccess` الموجود يتكفّل بتمرير ترويسة `Authorization` وتوجيه `/api/*`
إلى `api/index.php`، ويمنع تحميل `.env`.

---

## 6) التحقق بعد النشر

افتح في المتصفح:
```
https://<حسابك>.alwaysdata.net/api/health
```
يجب أن تحصل على JSON يوضّح إصدار PHP، اتصال قاعدة البيانات، توفّر cURL،
واختبار اتصال خارجي بـ Jikan. إن كان كل شيء أخضر، الباك-إند يعمل.

جرّب التسجيل:
```bash
curl -X POST https://<حسابك>.alwaysdata.net/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test","email":"t@t.com","password":"secret123"}'
```

---

## 7) توصيل تطبيق Flutter

عدّل `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl = 'https://<حسابك>.alwaysdata.net/api';
```
> لاحظ أن المسار ينتهي بـ `/api` (وليس `/v1`)، لأن راوتر الباك-إند يخدم
> جميع النقاط تحت `/api/*`.

الكتالوج (Trending/Details) يستدعي Jikan مباشرةً من التطبيق، لذا يعمل حتى
لو تعطّل الباك-إند، أما تسجيل الدخول والمفضلة والسجل فتمر عبر عنوانك أعلاه.

---

## استكشاف الأخطاء

- **500 عند أي نقطة:** راجع سجل الأخطاء في **Web → Sites → Logs**؛ غالبًا
  خطأ اتصال قاعدة البيانات (تحقق من `DB_HOST`/`DB_PASS`).
- **`/api/...` يرجع 404:** تأكد أن Document root هو مجلد `backend` وأن
  `.htaccess` مرفوع و`mod_rewrite` مفعّل (مفعّل افتراضيًا على alwaysdata).
- **`JWT_SECRET` placeholder:** المُوقّع يرفض العمل بسر غير مضبوط — ضع سرًّا
  حقيقيًا من `openssl rand -hex 32`.
- **الترويسة `Authorization` لا تصل:** `.htaccess` يمرّرها؛ إن استخدمت
  إعداد FastCGI مختلفًا فراجع سطر `SetEnvIf Authorization` فيه.
