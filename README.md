# Lab Bilgisayar Otomatik Yapilandirma Scripti

Windows lab ortamlari icin PowerShell tabanli otomasyon araci.

## Hizli Baslangic

PowerShell'i **Administrator** olarak acip asagidaki komutu calistirin:

```powershell
irm https://raw.githubusercontent.com/kenantasagal/lab-script/main/lab-setup.ps1 | iex
```

## Ozellikler

- **Otomatik Grup Yonetimi**: LAB-01 ile LAB-06 arasinda lab gruplari olusturur
- **Kullanici Yonetimi**: OgrenciXX kullanicilari olusturur (sifresiz)
- **Admin Yetkisi**: Olusturulan kullanicilar Administrator yetkisine sahip
- **Bilgisayar Adi Degisimi**: LAB-LL-BILXX formatinda otomatik isimlendirme
- **Kullanici Silme**: Kullanicilari dosyalari ile beraber guvenli sekilde siler
- **MAC Adresi/Seri No Bazli Tanimlama**: Toplu yapilandirma icin MAC adresi ve seri numarasi ile otomatik tanimlama
- **CSV Destegi**: Bilgisayar bilgilerini CSV'ye kaydetme ve CSV'den otomatik yapilandirma
- **Akilli Dogrulama**: Girdi kontrolu ve cakisma onleme
- **Uzaktan Calistirma**: `irm | iex` destegi

## Gereksinimler

- Windows 10/11 veya Windows Server 2016+
- PowerShell 5.1 veya uzeri
- Administrator yetkisi

## Kurulum

### Yerel Kurulum

```powershell
# Scripti indirin
git clone https://github.com/kullaniciadi/lab-script.git
cd lab-script

# Calistirin
.\lab-setup.ps1
```

### Uzaktan Calistirma (GitHub)

```powershell
# GitHub'dan dogrudan calistirin
irm https://raw.githubusercontent.com/kenantasagal/lab-script/main/lab-setup.ps1 | iex

# VEYA kisa URL ile
irm https://github.com/kenantasagal/lab-script/raw/main/lab-setup.ps1 | iex
```

**ONEMLI**: PowerShell'i mutlaka **Administrator** olarak acin!

## Kullanim

### Yeni Bilgisayar Yapilandirma

1. PowerShell'i **Administrator** olarak acin
2. Scripti calistirin
3. Menuden **1** secin
4. Sorulan bilgileri girin:
   - Lab numarasi (1-6)
   - Bilgisayar sirasi (1-99)
5. Ozeti kontrol edin ve onayin
6. Islemler tamamlaninca sistemi yeniden baslattin

### Kullanici Silme

1. Menuden **2** secin
2. Listeden silinecek kullaniciyi secin
3. Silme ozetini kontrol edin
4. Onaylayin (E/H)
5. Kullanici ve tum dosyalari silinecek

**UYARI**: Silme islemi geri alinamaz! C:\Users\OgrenciXX klasoru tamamen silinir.

### MAC Adresi/Seri No ile Toplu Yapilandirma

Bu ozellik, atolyede birden fazla bilgisayari yapilandirirken cok kullanislidir. Her bilgisayar kendi MAC adresine gore otomatik olarak taninir ve yapilandirilir.

#### Adim 1: Bilgisayar Bilgilerini Toplama

Her bilgisayarda:

1. Menuden **3** secin (Bilgisayar bilgilerini topla)
2. Script otomatik olarak su bilgileri toplar:
   - MAC Adresi
   - Seri Numarasi (BIOS)
   - Mevcut Bilgisayar Adi
   - IP Adresi
   - Windows Surumu
3. Bilgiler Desktop'a `bilgisayar-[MAC-ADRESI].csv` dosyasina kaydedilir

**Ornek dosya adi**: `bilgisayar-00-1B-44-11-3A-B7.csv`

#### Adim 2: CSV Dosyalarini Toplama ve Birlestirme

1. Tum bilgisayarlardan CSV dosyalarini toplayin (USB ile veya ag uzerinden)
2. Tum CSV dosyalarini tek bir dosyada birlestirin:
   - Excel'de tum CSV dosyalarini acin
   - Veya PowerShell ile: `Get-Content bilgisayar-*.csv | Select-Object -First 1 | Out-File bilgisayar-listesi.csv -Encoding UTF8`
   - Sonra tum dosyalarin icerigini (baslik haric) birlestirin
3. Birlesik dosyayi `bilgisayar-listesi.csv` olarak kaydedin

#### Adim 3: Lab ve Bilgisayar Numaralarini Doldurma

1. `bilgisayar-listesi.csv` dosyasini Excel'de acin
2. `LabNumber` ve `ComputerNumber` sutunlarini doldurun:
   - `LabNumber`: 1-6 arasi lab numarasi
   - `ComputerNumber`: 1-99 arasi bilgisayar sirasi
3. Dosyayi kaydedin

**Ornek CSV Icerigi:**
```csv
MACAddress,SerialNumber,ComputerName,IPAddress,WindowsVersion,CollectionDate,LabNumber,ComputerNumber,Status
00-1B-44-11-3A-B7,ABC123456,DESKTOP-ABC,192.168.1.10,Windows 10 Pro,2025-01-15 10:30:00,2,15,Beklemede
00-1B-44-11-3A-B8,ABC123457,DESKTOP-DEF,192.168.1.11,Windows 10 Pro,2025-01-15 10:31:00,2,16,Beklemede
```

#### Adim 4: Birlesik CSV'yi Her Bilgisayara Kopyalama

1. Birlesik `bilgisayar-listesi.csv` dosyasini her bilgisayarin Desktop'ina kopyalayin
2. USB ile veya ag paylasimi ile dagitin

#### Adim 5: Otomatik Yapilandirma

Her bilgisayarda:

1. Menuden **4** secin (CSV'den otomatik yapilandirma)
2. Script otomatik olarak:
   - Mevcut bilgisayarin MAC adresini okur
   - CSV dosyasinda bu MAC adresini bulur
   - CSV'deki Lab ve Bilgisayar numaralarina gore yapilandirma yapar
3. Yapilandirma tamamlandiginda CSV'deki durum "Tamamlandi" olarak guncellenir

**Avantajlar:**
- Her bilgisayar kendi MAC adresine gore otomatik taninir
- Hangi bilgisayarin hangi numara oldugunu bilmenize gerek yok
- Toplu yapilandirma cok daha hizli ve hatasiz
- CSV dosyasi Excel'de kolayca duzenlenebilir

## Ornekler

### Ornek 1: LAB-01'de 5. Bilgisayar

**Girdi:**
- Lab numarasi: `1`
- Bilgisayar sirasi: `5`

**Sonuc:**
- Grup: `LAB-01`
- Bilgisayar adi: `LAB-01-BIL05`
- Kullanici: `Ogrenci05`
- Yetki: Administrator

### Ornek 2: LAB-03'te 15. Bilgisayar

**Girdi:**
- Lab numarasi: `3`
- Bilgisayar sirasi: `15`

**Sonuc:**
- Grup: `LAB-03`
- Bilgisayar adi: `LAB-03-BIL15`
- Kullanici: `Ogrenci15`
- Yetki: Administrator

### Ornek 3: LAB-06'da 1. Bilgisayar

**Girdi:**
- Lab numarasi: `6`
- Bilgisayar sirasi: `1`

**Sonuc:**
- Grup: `LAB-06`
- Bilgisayar adi: `LAB-06-BIL01`
- Kullanici: `Ogrenci01`
- Yetki: Administrator

## Isimlendirme Kurallari

### Grup Adi
Format: `LAB-LL`
- `LL`: Lab numarasi (01-06, iki haneli)
- Ornek: `LAB-01`, `LAB-06`

### Bilgisayar Adi
Format: `LAB-LL-BILXX`
- `LL`: Lab numarasi (01-06, iki haneli)
- `XX`: Bilgisayar sirasi (01-99, iki haneli)
- Ornek: `LAB-03-BIL07`, `LAB-01-BIL25`

### Kullanici Adi
Format: `OgrenciXX`
- `XX`: Bilgisayar sirasi (01-99, iki haneli)
- **ONEMLI**: Lab numarasi kullanici adinda YOK!
- Ornek: `Ogrenci07`, `Ogrenci25`

## Yapilan Islemler

### Yeni Bilgisayar Yapilandirma (Secim 1)

1. **Grup Olusturma**: `LAB-XX` grubu yoksa olusturulur
2. **Kullanici Olusturma**: `OgrenciXX` kullanicisi yoksa olusturulur (sifresiz)
3. **LAB Grubuna Ekleme**: Kullanici lab grubuna eklenir
4. **Admin Yetkisi**: Kullanici `Administrators` grubuna eklenir
5. **Bilgisayar Adi**: Bilgisayar adi `LAB-LL-BILXX` olarak degistirilir
6. **Restart**: Degisikliklerin gecerli olmasi icin sistem yeniden baslatilir

### Kullanici Silme (Secim 2)

1. **Listeleme**: Mevcut ogrenci kullanicilari listelenir
2. **Secim**: Kullanicidan silinecek kullanici secilir
3. **Format Kontrolu**: Sadece `OgrenciXX` formatindaki kullanicilar silinebilir
4. **Var Mi Kontrolu**: Kullanicinin var oldugu dogrulanir
5. **Onay Alma**: Kullanicidan silme onayi alinir
6. **Kullanici Silme**: Yerel kullanici hesabi silinir
7. **Profil Silme**: `C:\Users\OgrenciXX` klasoru tum icerikle beraber silinir

### Bilgisayar Bilgilerini Toplama (Secim 3)

1. **Bilgi Toplama**: MAC adresi, seri numarasi, IP adresi, Windows surumu toplanir
2. **Dosya Olusturma**: Desktop'a `bilgisayar-[MAC-ADRESI].csv` dosyasi olusturulur
3. **Tek Kayit**: Her bilgisayar sadece kendi bilgisini yazar

### CSV'den Otomatik Yapilandirma (Secim 4)

1. **CSV Okuma**: Desktop'taki `bilgisayar-listesi.csv` dosyasi okunur
2. **MAC Eslestirme**: Mevcut bilgisayarin MAC adresi CSV'de aranir
3. **Yapilandirma**: CSV'deki Lab ve Bilgisayar numaralarina gore otomatik yapilandirma yapilir
4. **Durum Guncelleme**: CSV'deki durum "Tamamlandi" olarak guncellenir

## Guvenlik

- Admin yetkisi kontrolu yapilir
- Girdi dogrulama (1-6 ve 1-99 aralik)
- Kullanici/grup cakismasi onlenir
- Kullanici onayi alinir (hem olusturma hem silme icin)
- Kullanicilar sifresiz olusturulur (ilk oturumda sifre belirlenebilir)
- **Silme Guvenlik**: Sadece `OgrenciXX` formatindaki kullanicilar silinebilir (sistem kullanicilari korunur)

## Hata Yonetimi

Script asagidaki durumlarda hata verir ve islemi durdurur:

- Admin yetkisi yoksa
- Gecersiz lab numarasi (1-6 disinda)
- Gecersiz bilgisayar sirasi (1-99 disinda)
- Grup olusturulamazsa
- Kullanici olusturulamazsa
- Gruba ekleme basarisiz olursa
- Bilgisayar adi degistirilemezse

## Sik Sorulan Sorular

### Kullanicilar neden sifresiz?
Lab ortaminda hizli giris icin. Gerekirse Windows ilk oturumda sifre belirletebilir.

### Kullanicilar neden Administrator?
Yazilim kurulumu ve sistem ayarlari yapabilmeleri icin. Teknik egitim lablarinda gerekli.

### Ayni bilgisayar numarasini farkli lablarda kullanabilir miyim?
Evet! `Ogrenci07` hem LAB-01'de hem LAB-03'te olabilir. Bilgisayar adlari farkli olacak:
- LAB-01-BIL07
- LAB-03-BIL07

### Script zaten var olan kullaniciyi ezer mi?
Hayir! Kullanici varsa "zaten mevcut" mesaji verir ve devam eder.

### Bilgisayar adini degistirmeden test edebilir miyim?
Evet, kodu duzenleyerek `Set-ComputerNameSafely` satirini yorum satirina cevirin.

### Kullanici silerken dosyalar geri getirebilir miyim?
Hayir! Silme islemi kalicidir. Onemli dosyalar varsa once yedek alin.

### Neden sadece OgrenciXX formatindaki kullanicilar silinebiliyor?
Guvenlik icin. Boylece yanlis islemle Administrator, System gibi onemli kullanicilarin silinmesi onlenir.

### Kullanici silindiginde gruplardan da cikar mi?
Evet! Windows otomatik olarak kullaniciyi tum gruplardan (LAB-XX, Administrators) cikarir.

### MAC adresi bazli tanimlama nasil calisir?
Her bilgisayar kendi MAC adresini kullanarak CSV dosyasinda kendini bulur. Bu sayede hangi bilgisayarin hangi numara oldugunu bilmenize gerek kalmaz.

### CSV dosyalarini nasil birlestiririm?
Excel'de tum CSV dosyalarini acip, baslik satirini bir kez yazip, diger dosyalarin icerigini (baslik haric) kopyalayin. Veya PowerShell ile birlestirebilirsiniz.

### CSV dosyasi nereye kaydediliyor?
Her bilgisayar kendi bilgisini Desktop klasorune `bilgisayar-[MAC-ADRESI].csv` adiyla kaydeder.

### Birlesik CSV dosyasini her bilgisayara nasil kopyalarim?
USB bellek ile, ag paylasimi ile veya uzaktan erisim ile her bilgisayarin Desktop'ina `bilgisayar-listesi.csv` dosyasini kopyalayin.

## Sorun Giderme

### "Script disabled" hatasi
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Administrator yetkisi gerekli" hatasi
PowerShell'i sag tiklayip **"Run as Administrator"** ile acin.

### Grup olusturulamiyor
Windows Home surumunde yerel grup yonetimi kisitlidir. Pro/Enterprise gerekir.

## Katki

1. Projeyi fork edin
2. Degisikliklerinizi yapin
3. Pull request gonderin

## Lisans

Bu script egitim amacli olarak gelistirilmistir. Serbestce kullanabilir ve degistirebilirsiniz.

## Yazar

Lab Otomasyon Ekibi

## Surum Gecmisi

### v1.2 (2025-01-15)
- **YENI**: MAC adresi/Seri numarasi bazli tanimlama ozelligi
- **YENI**: Bilgisayar bilgilerini CSV'ye kaydetme
- **YENI**: CSV'den otomatik yapilandirma
- Her bilgisayar kendi bilgisini ayrı CSV dosyasina yazar
- Toplu yapilandirma icin CSV birlestirme destegi
- Kullanici silme menüsünde liste gosterimi eklendi
- Modern ve kullanici dostu arayuz iyilestirmeleri

### v1.1 (2025-12-31)
- **YENI**: Kullanici silme ozelligi eklendi
- Kullanicilari dosyalari ile beraber silme
- Guvenlik: Sadece OgrenciXX formatindaki kullanicilar silinebilir
- Silme isleminde onay mekanizmasi

### v1.0 (2025-12-31)
- Ilk surum
- Temel lab yapilandirma ozellikleri
- Uzaktan calistirma destegi
- Admin yetkisi eklendi
- Sifresiz kullanici olusturma

---

**Not**: Bu script Windows yerel bilgisayarlarda calisir. Domain ortami icin Active Directory komutlari gerekir.
