# OfficeFlow

OfficeFlow, ofis giriş/çıkışlarını geofence üzerinden izleyen ve çalışma süresi raporları üreten bir iOS uygulamasıdır.

## Özellikler

- Ofis konumu (enlem, boylam, yarıçap) tanımlama
- Geofence tabanlı otomatik giriş/çıkış olayı üretimi
- Manuel giriş/çıkış düzeltmesi ve denetim kaydı
- Günlük/haftalık/aylık hedef tanımlama
- Dashboard, raporlar ve zaman çizelgesi ekranları
- İzin durumu ve takip hazır olma durumu izleme

## Proje Yapısı

- `OfcHoursApp/Features`: Ekranlar (`Dashboard`, `Reports`, `Timeline`, `Settings`, `Onboarding`)
- `OfcHoursApp/Support`: Uygulama durumu, domain servisleri, modeller ve tasarım sistemi
- `OfcHoursApp.xcodeproj`: Xcode proje dosyası

## Gereksinimler

- Xcode (güncel sürüm)
- iOS Simulator veya gerçek cihaz

## Lokal Çalıştırma

1. Projeyi aç:
```bash
open OfcHoursApp.xcodeproj
```
2. Xcode içinde `OfcHoursApp` scheme seçip çalıştır.

Komut satırından build:
```bash
xcodebuild -project OfcHoursApp.xcodeproj -scheme OfcHoursApp -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## BMAD Local Live Board

BMAD tarafinda uretilen epic/story durumlarini local dosyalardan canli izlemek icin:

1. Serveri baslat:
```bash
./scripts/run-bmad-live-board.sh
```
2. Tarayicida ac:
```text
http://127.0.0.1:4173/bmad-local-dashboard.html
```
3. Gerekirse `BMAD Output Path` alanina kendi path'ini gir:
```text
/Users/serkan/Documents/ofchours/_bmad-output
```

Not:
- Veri kaynagi: `implementation-artifacts/sprint-status.yaml` + story markdown dosyalari
- Ekran otomatik yenileme ile canli takip eder

## İzinler

- Konum: Sağlıklı arka plan takibi için `Always` izni gerekir.
- Bildirim: Takip/uyarı deneyimi için önerilir.

## Versiyonlama

Branch, commit ve rollback akışı için:

- `VERSIONING.md`

## Katkı

Katkı kuralları için:

- `CONTRIBUTING.md`

## Lisans

Bu proje MIT lisansı ile lisanslanmıştır:

- `LICENSE`
