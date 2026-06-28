import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({
    super.key,
    this.url = 'https://topshirdi.uz/privacy',
    this.title = 'Maxfiylik siyosati',
  });

  final String url;
  final String title;

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onHttpError: (error) async {
            if (!mounted || _usingFallback) return;
            if (error.response?.statusCode == 404 ||
                error.response?.statusCode == 403 ||
                error.response?.statusCode == 500) {
              _usingFallback = true;
              await _controller.loadHtmlString(_fallbackHtml());
            }
          },
          onWebResourceError: (_) async {
            if (!mounted || _usingFallback) return;
            _usingFallback = true;
            await _controller.loadHtmlString(_fallbackHtml());
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

String _fallbackHtml() {
  return '''
<!doctype html>
<html lang="uz">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Maxfiylik siyosati - Topshirdi</title>
  <style>
    :root { color-scheme: light dark; }
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f6f8fc; color: #1f2937; }
    @media (prefers-color-scheme: dark) { body { background: #0f172a; color: #e5e7eb; } .card { background: #111827; border-color: #223049; } a { color: #7db4ff; } }
    .wrap { max-width: 900px; margin: 0 auto; padding: 24px 16px 40px; }
    .hero { background: linear-gradient(135deg, #0d4fc9, #5f7cff); color: #fff; border-radius: 22px; padding: 28px 22px; margin-bottom: 18px; }
    .hero h1 { margin: 0 0 10px; font-size: 30px; }
    .hero p { margin: 0; line-height: 1.6; opacity: .96; }
    .card { background: #fff; border: 1px solid #d7dfeb; border-radius: 20px; padding: 20px; margin-bottom: 14px; box-shadow: 0 8px 24px rgba(15, 23, 42, .05); }
    h2 { margin: 0 0 10px; font-size: 20px; }
    h3 { margin: 18px 0 8px; font-size: 16px; }
    p, li { line-height: 1.7; font-size: 15px; }
    ul { margin: 8px 0 0 18px; }
    .muted { color: #6b7280; }
    .footer { margin-top: 18px; font-size: 14px; }
    .pill { display: inline-block; padding: 8px 12px; border-radius: 999px; background: rgba(255,255,255,.16); margin-top: 12px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>Maxfiylik siyosati</h1>
      <p>Topshirdi foydalanuvchi ma'lumotlarini qanday yig'ishi, ishlatishi va himoya qilishini tushuntiradi.</p>
      <div class="pill">Oxirgi yangilanish: 2026-06-14</div>
    </div>

    <div class="card">
      <h2>1. Yig'iladigan ma'lumotlar</h2>
      <p>Topshirdi quyidagi ma'lumotlarni yig'ishi mumkin:</p>
      <ul>
        <li>Ism</li>
        <li>Email manzil</li>
        <li>Kirish ma'lumotlari</li>
        <li>O'rganish jarayoni va progress</li>
        <li>Test natijalari va imtihon statistikasi</li>
        <li>Ilova ishlashi uchun zarur qurilma ma'lumotlari</li>
      </ul>
    </div>

    <div class="card">
      <h2>2. Ma'lumotlardan foydalanish</h2>
      <ul>
        <li>Hisob yaratish va boshqarish</li>
        <li>Progressni saqlash</li>
        <li>Statistika ko'rsatish</li>
        <li>Platforma sifatini yaxshilash</li>
        <li>Ta'lim xizmatlarini taqdim etish</li>
      </ul>
    </div>

    <div class="card">
      <h2>3. Ma'lumot ulashish</h2>
      <p>Topshirdi foydalanuvchi ma'lumotlarini sotmaydi.</p>
      <p>Ma'lumotlar qonun talab qilgan holatlardan tashqari uchinchi tomonlarga berilmaydi.</p>
    </div>

    <div class="card">
      <h2>4. Xavfsizlik</h2>
      <p>Topshirdi foydalanuvchi ma'lumotlarini himoya qilish uchun oqilona texnik choralarni qo'llaydi.</p>
    </div>

    <div class="card">
      <h2>5. Foydalanuvchi huquqlari</h2>
      <ul>
        <li>Hisobni o'chirishni so'rash</li>
        <li>Ma'lumotlarni tuzatishni so'rash</li>
        <li>Qo'llab-quvvatlashga murojaat qilish</li>
      </ul>
    </div>

    <div class="card">
      <h2>6. Bolalar maxfiyligi</h2>
      <p>Platforma ta'lim maqsadlari uchun mo'ljallangan.</p>
    </div>

    <div class="card">
      <h2>7. Siyosat o'zgarishlari</h2>
      <p>Topshirdi ushbu maxfiylik siyosatini kelajakda yangilashi mumkin.</p>
    </div>

    <div class="card footer">
      <h2>Aloqa</h2>
      <p><a href="mailto:support@topshirdi.uz">support@topshirdi.uz</a></p>
      <p><a href="https://topshirdi.uz">https://topshirdi.uz</a></p>
      <p class="muted">Agar asosiy sahifa javob bermasa, ushbu ichki variant ko'rsatiladi.</p>
    </div>
  </div>
</body>
</html>
''';
}
