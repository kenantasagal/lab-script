<#
.SYNOPSIS
    Okul lab bilgisayarlari icin otomatik konfigurasyonu yapar.

.DESCRIPTION
    - LAB-01 ile LAB-06 arasinda lab gruplari olusturur
    - OgrenciXX kullanicilari olusturur
    - Bilgisayar adini LAB-LL-BILXX formatinda degistirir
    - Uzaktan calistirma destekler: irm https://... | iex

.NOTES
    Yazar: Lab Otomasyon
    Versiyon: 1.0
#>

# ==============================
# YARDIMCI FONKSIYONLAR
# ==============================

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                    ║" -ForegroundColor Cyan
    Write-Host "║     " -NoNewline -ForegroundColor Cyan
    Write-Host "LAB BILGISAYAR YAPILANDIRMA ARACI" -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "     ║" -ForegroundColor Cyan
    Write-Host "║                                                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "1" -NoNewline -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Yeni ogrenci bilgisayari konfigure et" -ForegroundColor White
    Write-Host "  ├──────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "2" -NoNewline -ForegroundColor Magenta
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Kullanici sil (dosyalari ile beraber)" -ForegroundColor White
    Write-Host "  ├──────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "3" -NoNewline -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Bilgisayar bilgilerini topla (CSV)" -ForegroundColor White
    Write-Host "  ├──────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "4" -NoNewline -ForegroundColor Green
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "CSV'den otomatik yapilandirma" -ForegroundColor White
    Write-Host "  ├──────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "5" -NoNewline -ForegroundColor Blue
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Hizli otomatik yapilandirma (CSV kontrol)" -ForegroundColor White
    Write-Host "  ├──────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "0" -NoNewline -ForegroundColor Red
    Write-Host "  │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Cikis" -ForegroundColor White
    Write-Host "  └──────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-ValidatedInput {
    param(
        [string]$Prompt,
        [int]$Min,
        [int]$Max
    )

    while ($true) {
        $input = Read-Host $Prompt

        # Bos giris kontrolu
        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Hata: Bos birakilamaz!" -ForegroundColor Red
            continue
        }

        # Sayi kontrolu
        $number = 0
        if (-not [int]::TryParse($input, [ref]$number)) {
            Write-Host "Hata: Sadece sayi giriniz!" -ForegroundColor Red
            continue
        }

        # Aralik kontrolu
        if ($number -lt $Min -or $number -gt $Max) {
            Write-Host "Hata: $Min ile $Max arasinda bir sayi giriniz!" -ForegroundColor Red
            continue
        }

        return $number
    }
}

function Format-TwoDigit {
    param([int]$Number)
    return $Number.ToString("00")
}

function Test-LocalGroupExists {
    param([string]$GroupName)

    try {
        $group = Get-LocalGroup -Name $GroupName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-LocalUserExists {
    param([string]$UserName)

    try {
        $user = Get-LocalUser -Name $UserName -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Get-StudentUsers {
    # Sistem kullanici isimleri (silinmemeli)
    $systemUsers = @('Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount')
    
    try {
        # Tum yerel kullanicilari al
        $allUsers = Get-LocalUser
        
        # Sadece OgrenciXX formatindaki kullanicilari filtrele ve sistem kullanicilarini hariç tut
        $studentUsers = $allUsers | Where-Object { 
            $_.Name -match '^Ogrenci\d{2}$' -and 
            $_.Name -notin $systemUsers
        } | Sort-Object Name
        
        return $studentUsers
    }
    catch {
        Write-Host "[HATA] Kullanicilar listelenemedi: $_" -ForegroundColor Red
        return @()
    }
}

function Get-ComputerInfo {
    # Bilgisayar bilgilerini topla
    $info = @{}
    
    try {
        # Bilgisayar adi
        $info.ComputerName = $env:COMPUTERNAME
        
        # MAC adresi (ilk aktif ağ adaptörü)
        $networkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.PhysicalMediaType -ne 'Unspecified' } | Select-Object -First 1
        if ($networkAdapter) {
            $info.MACAddress = $networkAdapter.MacAddress
        }
        else {
            $info.MACAddress = "Bulunamadi"
        }
        
        # Seri numarasi (BIOS)
        try {
            $bios = Get-WmiObject -Class Win32_BIOS -ErrorAction Stop
            $info.SerialNumber = $bios.SerialNumber
        }
        catch {
            $info.SerialNumber = "Bulunamadi"
        }
        
        # IP adresi
        $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
        if ($ipAddress) {
            $info.IPAddress = $ipAddress
        }
        else {
            $info.IPAddress = "Bulunamadi"
        }
        
        # Windows sürümü
        $info.WindowsVersion = (Get-CimInstance Win32_OperatingSystem).Caption
        
        # Tarih
        $info.CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        return $info
    }
    catch {
        Write-Host "[HATA] Bilgisayar bilgileri toplanamadi: $_" -ForegroundColor Red
        return $null
    }
}

function Export-ComputerInfo {
    param([string]$FilePath = "")
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "BILGISAYAR BILGILERINI TOPLAMA" -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $info = Get-ComputerInfo
    
    if ($null -eq $info) {
        Write-Host "  ✗ Bilgisayar bilgileri toplanamadi!" -ForegroundColor Red
        return $false
    }
    
    # Dosya yolu belirtilmemisse, Desktop'a MAC adresine gore dosya adi ile kaydet
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        # MAC adresindeki : karakterlerini - ile degistir
        $macFileName = $info.MACAddress -replace ':', '-'
        $fileName = "bilgisayar-$macFileName.csv"
        $FilePath = Join-Path $desktopPath $fileName
    }
    # Relative path ise tam yola cevir
    elseif ($FilePath -match '^\.\\') {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $fileName = Split-Path $FilePath -Leaf
        $FilePath = Join-Path $desktopPath $fileName
    }
    
    Write-Host "  📁 Dosya konumu: " -NoNewline -ForegroundColor Cyan
    Write-Host "$FilePath" -ForegroundColor Yellow
    Write-Host ""
    
    # Yeni kayit olustur (sadece bu bilgisayarin bilgisi)
    $newRecord = [PSCustomObject]@{
        MACAddress = $info.MACAddress
        SerialNumber = $info.SerialNumber
        ComputerName = $info.ComputerName
        IPAddress = $info.IPAddress
        WindowsVersion = $info.WindowsVersion
        CollectionDate = $info.CollectionDate
        LabNumber = ""
        ComputerNumber = ""
        Status = "Beklemede"
    }
    
    # Dosya var mi kontrol et
    $fileExists = Test-Path $FilePath
    
    if ($fileExists) {
        Write-Host "  ⚠  Dosya zaten mevcut, guncelleniyor..." -ForegroundColor Yellow
        Write-Host ""
    }
    
    # CSV'ye kaydet (sadece bu bilgisayarin bilgisi - tek satir)
    $newRecord | Export-Csv -Path $FilePath -Encoding UTF8 -NoTypeInformation
    
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "TOPLANAN BILGILER" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Green
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "MAC Adresi     : " -NoNewline -ForegroundColor White
    Write-Host "$($info.MACAddress)" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "Seri No        : " -NoNewline -ForegroundColor White
    Write-Host "$($info.SerialNumber)" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "Bilgisayar Adi : " -NoNewline -ForegroundColor White
    Write-Host "$($info.ComputerName)" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "IP Adresi      : " -NoNewline -ForegroundColor White
    Write-Host "$($info.IPAddress)" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Green
    Write-Host "Windows        : " -NoNewline -ForegroundColor White
    Write-Host "$($info.WindowsVersion)" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ✓ Bilgiler kaydedildi: " -NoNewline -ForegroundColor Green
    Write-Host "$FilePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  📝 Sonraki adimlar:" -ForegroundColor Yellow
    Write-Host "     1. Tum bilgisayarlardan CSV dosyalarini toplayin" -ForegroundColor White
    Write-Host "     2. Tum CSV dosyalarini bir dosyada birlestirin (bilgisayar-listesi.csv)" -ForegroundColor White
    Write-Host "     3. Birlesik CSV dosyasinda LabNumber ve ComputerNumber sutunlarini doldurun" -ForegroundColor White
    Write-Host "     4. Birlesik CSV dosyasini her bilgisayarin Desktop'ina kopyalayin" -ForegroundColor White
    Write-Host "     5. Her bilgisayarda 'CSV'den otomatik yapilandirma' secenegini kullanin" -ForegroundColor White
    Write-Host ""
    
    return $true
}

function Import-AndConfigureFromCSV {
    param([string]$FilePath = "")
    
    # Dosya yolu belirtilmemisse, Desktop'ta ara
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $FilePath = Join-Path $desktopPath "bilgisayar-listesi.csv"
    }
    # Relative path ise tam yola cevir
    elseif ($FilePath -match '^\.\\') {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $fileName = Split-Path $FilePath -Leaf
        $FilePath = Join-Path $desktopPath $fileName
    }
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "CSV'DEN OTOMATIK YAPILANDIRMA" -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  📁 Dosya konumu: " -NoNewline -ForegroundColor Cyan
    Write-Host "$FilePath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  💡 Bu secenek birlesik CSV dosyasini kullanir." -ForegroundColor Yellow
    Write-Host "     Tum bilgisayarlardan toplanan CSV dosyalarini birlestirip" -ForegroundColor White
    Write-Host "     LabNumber ve ComputerNumber sutunlarini doldurduktan sonra" -ForegroundColor White
    Write-Host "     bu dosyayi her bilgisayarin Desktop'ina kopyalayin." -ForegroundColor White
    Write-Host ""
    
    # Dosya var mi kontrol et
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ✗ CSV dosyasi bulunamadi: $FilePath" -ForegroundColor Red
        Write-Host ""
        Write-Host "  💡 Once tum bilgisayarlardan CSV dosyalarini toplayip birlestirin." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # CSV'yi oku
    try {
        $computers = Import-Csv -Path $FilePath -Encoding UTF8
    }
    catch {
        Write-Host "  ✗ CSV dosyasi okunamadi: $_" -ForegroundColor Red
        return $false
    }
    
    if ($computers.Count -eq 0) {
        Write-Host "  ⚠  CSV dosyasinda kayit bulunamadi!" -ForegroundColor Yellow
        return $false
    }
    
    # Mevcut bilgisayarin MAC adresini al
    $currentInfo = Get-ComputerInfo
    if ($null -eq $currentInfo) {
        Write-Host "  ✗ Bilgisayar bilgileri alinamadi!" -ForegroundColor Red
        return $false
    }
    
    # Bu bilgisayari CSV'de bul
    $currentComputer = $computers | Where-Object { $_.MACAddress -eq $currentInfo.MACAddress }
    
    if (-not $currentComputer) {
        Write-Host "  ✗ Bu bilgisayar CSV dosyasinda bulunamadi!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Mevcut MAC Adresi: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($currentInfo.MACAddress)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  💡 Once 'Bilgisayar bilgilerini topla' secenegini kullanin." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # Lab ve bilgisayar numarasi kontrol et
    if ([string]::IsNullOrWhiteSpace($currentComputer.LabNumber) -or [string]::IsNullOrWhiteSpace($currentComputer.ComputerNumber)) {
        Write-Host "  ⚠  Bu bilgisayar icin Lab ve Bilgisayar numarasi atanmamis!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "BILGISAYAR BILGILERI" -ForegroundColor White -BackgroundColor DarkYellow
        Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Yellow
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "MAC Adresi     : " -NoNewline -ForegroundColor White
        Write-Host "$($currentComputer.MACAddress)" -ForegroundColor Cyan
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Bilgisayar Adi : " -NoNewline -ForegroundColor White
        Write-Host "$($currentComputer.ComputerName)" -ForegroundColor Cyan
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Lab No         : " -NoNewline -ForegroundColor White
        if ($currentComputer.LabNumber) {
            Write-Host "$($currentComputer.LabNumber)" -ForegroundColor Green
        }
        else {
            Write-Host "Henuz atanmadi" -ForegroundColor Red
        }
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Bilgisayar No  : " -NoNewline -ForegroundColor White
        if ($currentComputer.ComputerNumber) {
            Write-Host "$($currentComputer.ComputerNumber)" -ForegroundColor Green
        }
        else {
            Write-Host "Henuz atanmadi" -ForegroundColor Red
        }
        Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  💡 CSV dosyasini acip LabNumber ve ComputerNumber sutunlarini doldurun." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # Lab ve bilgisayar numarasini dogrula
    $labNumber = 0
    $computerNumber = 0
    
    if (-not [int]::TryParse($currentComputer.LabNumber, [ref]$labNumber) -or $labNumber -lt 1 -or $labNumber -gt 6) {
        Write-Host "  ✗ Gecersiz Lab numarasi: $($currentComputer.LabNumber)" -ForegroundColor Red
        Write-Host "     Lab numarasi 1-6 arasinda olmalidir." -ForegroundColor Yellow
        return $false
    }
    
    if (-not [int]::TryParse($currentComputer.ComputerNumber, [ref]$computerNumber) -or $computerNumber -lt 1 -or $computerNumber -gt 99) {
        Write-Host "  ✗ Gecersiz Bilgisayar numarasi: $($currentComputer.ComputerNumber)" -ForegroundColor Red
        Write-Host "     Bilgisayar numarasi 1-99 arasinda olmalidir." -ForegroundColor Yellow
        return $false
    }
    
    # Isimleri turet
    $labNumberFormatted = Format-TwoDigit -Number $labNumber
    $computerNumberFormatted = Format-TwoDigit -Number $computerNumber
    
    $groupName = "LAB-$labNumberFormatted"
    $computerName = "LAB-$labNumberFormatted-BIL$computerNumberFormatted"
    $userName = "Ogrenci$computerNumberFormatted"
    
    # Ozet goster
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "YAPILACAK ISLEMLER" -ForegroundColor White -BackgroundColor DarkYellow
    Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "MAC Adresi     : " -NoNewline -ForegroundColor White
    Write-Host "$($currentComputer.MACAddress)" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Grup adi       : " -NoNewline -ForegroundColor White
    Write-Host "$groupName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Bilgisayar adi : " -NoNewline -ForegroundColor White
    Write-Host "$computerName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Kullanici adi  : " -NoNewline -ForegroundColor White
    Write-Host "$userName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Yetki seviyesi : " -NoNewline -ForegroundColor White
    Write-Host "Administrator (Tam yetki)" -ForegroundColor Green
    Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    
    # Onay al
    $confirmation = Read-Host "Devam etmek istiyor musunuz? (E/H)"
    if ($confirmation -notmatch '^[Ee]$') {
        Write-Host "Islem iptal edildi." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host ""
    Write-Host "Islemler baslatiliyor..." -ForegroundColor Cyan
    Write-Host ""
    
    # Islemleri yap
    $success = $true
    
    # Grup olustur
    if (-not (New-LabGroup -GroupName $groupName)) {
        $success = $false
    }
    
    # Kullanici olustur
    if (-not (New-StudentUser -UserName $userName)) {
        $success = $false
    }
    
    # Kullaniciyi LAB grubuna ekle
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName $groupName)) {
            $success = $false
        }
    }
    
    # Kullaniciyi Administrators grubuna ekle (admin yetkisi)
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName "Administrators")) {
            $success = $false
        }
    }
    
    # Bilgisayar adini degistir
    if ($success) {
        if (-not (Set-ComputerNameSafely -NewName $computerName)) {
            $success = $false
        }
    }
    
    # CSV'de durumu guncelle
    if ($success) {
        try {
            $computers | Where-Object { $_.MACAddress -eq $currentInfo.MACAddress } | ForEach-Object {
                $_.Status = "Tamamlandi"
            }
            $computers | Export-Csv -Path $FilePath -Encoding UTF8 -NoTypeInformation
        }
        catch {
            Write-Host "[BILGI] CSV durumu guncellenemedi: $_" -ForegroundColor Yellow
        }
    }
    
    # Sonuc
    Write-Host ""
    if ($success) {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "║     " -NoNewline -ForegroundColor Green
        Write-Host "✓ YAPILANDIRMA TAMAMLANDI!" -NoNewline -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "     ║" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        
        # Restart gerekiyor mu kontrol et
        if ($env:COMPUTERNAME -ne $computerName) {
            Write-Host "ONEMLI: Bilgisayar adinin gecerli olmasi icin sistemi yeniden baslatmaniz gerekiyor." -ForegroundColor Magenta
            Write-Host ""
            $restart = Read-Host "Simdi yeniden baslatmak istiyor musunuz? (E/H)"
            if ($restart -match '^[Ee]$') {
                Write-Host "Sistem 10 saniye icinde yeniden baslatilacak..." -ForegroundColor Yellow
                shutdown /r /t 10 /c "Lab yapilandirma sonrasi yeniden baslatma"
            }
            else {
                Write-Host "Lutfen daha sonra sistemi yeniden baslatin." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "║   " -NoNewline -ForegroundColor Red
        Write-Host "✗ YAPILANDIRMA TAMAMLANAMADI!" -NoNewline -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "   ║" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  ⚠  " -NoNewline -ForegroundColor Yellow
        Write-Host "Lutfen hatalari kontrol edin." -ForegroundColor Yellow
    }
    
    return $success
}

function Start-QuickAutoConfigure {
    param([string]$FilePath = "")
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "HIZLI OTOMATIK YAPILANDIRMA" -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🔍 CSV dosyasi kontrol ediliyor..." -ForegroundColor Cyan
    Write-Host ""
    
    # Dosya yolu belirtilmemisse, Desktop'ta ara
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $FilePath = Join-Path $desktopPath "bilgisayar-listesi.csv"
    }
    # Relative path ise tam yola cevir
    elseif ($FilePath -match '^\.\\') {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $fileName = Split-Path $FilePath -Leaf
        $FilePath = Join-Path $desktopPath $fileName
    }
    
    # Dosya var mi kontrol et
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ✗ CSV dosyasi bulunamadi: $FilePath" -ForegroundColor Red
        Write-Host ""
        Write-Host "  💡 Once tum bilgisayarlardan CSV dosyalarini toplayip birlestirin." -ForegroundColor Yellow
        Write-Host "     Menuden '3' secenegini kullanarak bilgisayar bilgilerini toplayin." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # CSV'yi oku
    try {
        $computers = Import-Csv -Path $FilePath -Encoding UTF8
    }
    catch {
        Write-Host "  ✗ CSV dosyasi okunamadi: $_" -ForegroundColor Red
        return $false
    }
    
    if ($computers.Count -eq 0) {
        Write-Host "  ⚠  CSV dosyasinda kayit bulunamadi!" -ForegroundColor Yellow
        return $false
    }
    
    # Mevcut bilgisayarin MAC adresini al
    $currentInfo = Get-ComputerInfo
    if ($null -eq $currentInfo) {
        Write-Host "  ✗ Bilgisayar bilgileri alinamadi!" -ForegroundColor Red
        return $false
    }
    
    # Bu bilgisayari CSV'de bul
    $currentComputer = $computers | Where-Object { $_.MACAddress -eq $currentInfo.MACAddress }
    
    if (-not $currentComputer) {
        Write-Host "  ✗ Bu bilgisayar CSV dosyasinda bulunamadi!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Mevcut MAC Adresi: " -NoNewline -ForegroundColor Yellow
        Write-Host "$($currentInfo.MACAddress)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  💡 Once 'Bilgisayar bilgilerini topla' secenegini kullanin." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # Lab ve bilgisayar numarasi kontrol et
    if ([string]::IsNullOrWhiteSpace($currentComputer.LabNumber) -or [string]::IsNullOrWhiteSpace($currentComputer.ComputerNumber)) {
        Write-Host "  ⚠  Bu bilgisayar icin Lab ve Bilgisayar numarasi atanmamis!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "BILGISAYAR BILGILERI" -ForegroundColor White -BackgroundColor DarkYellow
        Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Yellow
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "MAC Adresi     : " -NoNewline -ForegroundColor White
        Write-Host "$($currentComputer.MACAddress)" -ForegroundColor Cyan
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Bilgisayar Adi : " -NoNewline -ForegroundColor White
        Write-Host "$($currentComputer.ComputerName)" -ForegroundColor Cyan
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Lab No         : " -NoNewline -ForegroundColor White
        if ($currentComputer.LabNumber) {
            Write-Host "$($currentComputer.LabNumber)" -ForegroundColor Green
        }
        else {
            Write-Host "Henuz atanmadi" -ForegroundColor Red
        }
        Write-Host "  │  " -NoNewline -ForegroundColor Yellow
        Write-Host "Bilgisayar No  : " -NoNewline -ForegroundColor White
        if ($currentComputer.ComputerNumber) {
            Write-Host "$($currentComputer.ComputerNumber)" -ForegroundColor Green
        }
        else {
            Write-Host "Henuz atanmadi" -ForegroundColor Red
        }
        Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  💡 CSV dosyasini acip LabNumber ve ComputerNumber sutunlarini doldurun." -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    
    # Lab ve bilgisayar numarasini dogrula
    $labNumber = 0
    $computerNumber = 0
    
    if (-not [int]::TryParse($currentComputer.LabNumber, [ref]$labNumber) -or $labNumber -lt 1 -or $labNumber -gt 6) {
        Write-Host "  ✗ Gecersiz Lab numarasi: $($currentComputer.LabNumber)" -ForegroundColor Red
        Write-Host "     Lab numarasi 1-6 arasinda olmalidir." -ForegroundColor Yellow
        return $false
    }
    
    if (-not [int]::TryParse($currentComputer.ComputerNumber, [ref]$computerNumber) -or $computerNumber -lt 1 -or $computerNumber -gt 99) {
        Write-Host "  ✗ Gecersiz Bilgisayar numarasi: $($currentComputer.ComputerNumber)" -ForegroundColor Red
        Write-Host "     Bilgisayar numarasi 1-99 arasinda olmalidir." -ForegroundColor Yellow
        return $false
    }
    
    # Isimleri turet
    $labNumberFormatted = Format-TwoDigit -Number $labNumber
    $computerNumberFormatted = Format-TwoDigit -Number $computerNumber
    
    $groupName = "LAB-$labNumberFormatted"
    $computerName = "LAB-$labNumberFormatted-BIL$computerNumberFormatted"
    $userName = "Ogrenci$computerNumberFormatted"
    
    # Bilgileri goster
    Write-Host "  ✓ Bilgisayar CSV'de tanimli!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Cyan
    Write-Host "YAPILANDIRMA BILGILERI" -ForegroundColor White -BackgroundColor DarkCyan
    Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Cyan
    Write-Host "Grup adi       : " -NoNewline -ForegroundColor White
    Write-Host "$groupName" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Cyan
    Write-Host "Bilgisayar adi : " -NoNewline -ForegroundColor White
    Write-Host "$computerName" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Cyan
    Write-Host "Kullanici adi  : " -NoNewline -ForegroundColor White
    Write-Host "$userName" -ForegroundColor Yellow
    Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  🚀 Otomatik yapilandirma baslatiliyor..." -ForegroundColor Green
    Write-Host ""
    
    # Islemleri yap (onay almadan)
    $success = $true
    
    # Grup olustur
    if (-not (New-LabGroup -GroupName $groupName)) {
        $success = $false
    }
    
    # Kullanici olustur
    if (-not (New-StudentUser -UserName $userName)) {
        $success = $false
    }
    
    # Kullaniciyi LAB grubuna ekle
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName $groupName)) {
            $success = $false
        }
    }
    
    # Kullaniciyi Administrators grubuna ekle (admin yetkisi)
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName "Administrators")) {
            $success = $false
        }
    }
    
    # Bilgisayar adini degistir
    if ($success) {
        if (-not (Set-ComputerNameSafely -NewName $computerName)) {
            $success = $false
        }
    }
    
    # CSV'de durumu guncelle
    if ($success) {
        try {
            $computers | Where-Object { $_.MACAddress -eq $currentInfo.MACAddress } | ForEach-Object {
                $_.Status = "Tamamlandi"
            }
            $computers | Export-Csv -Path $FilePath -Encoding UTF8 -NoTypeInformation
        }
        catch {
            Write-Host "[BILGI] CSV durumu guncellenemedi: $_" -ForegroundColor Yellow
        }
    }
    
    # Sonuc
    Write-Host ""
    if ($success) {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "║     " -NoNewline -ForegroundColor Green
        Write-Host "✓ YAPILANDIRMA TAMAMLANDI!" -NoNewline -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "     ║" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Olusturulan:" -ForegroundColor Cyan
        Write-Host "    • Grup: " -NoNewline -ForegroundColor White
        Write-Host "$groupName" -ForegroundColor Yellow
        Write-Host "    • Bilgisayar: " -NoNewline -ForegroundColor White
        Write-Host "$computerName" -ForegroundColor Yellow
        Write-Host "    • Kullanici: " -NoNewline -ForegroundColor White
        Write-Host "$userName" -ForegroundColor Yellow
        Write-Host ""
        
        # Restart gerekiyor mu kontrol et
        if ($env:COMPUTERNAME -ne $computerName) {
            Write-Host "ONEMLI: Bilgisayar adinin gecerli olmasi icin sistemi yeniden baslatmaniz gerekiyor." -ForegroundColor Magenta
            Write-Host ""
            $restart = Read-Host "Simdi yeniden baslatmak istiyor musunuz? (E/H)"
            if ($restart -match '^[Ee]$') {
                Write-Host "Sistem 10 saniye icinde yeniden baslatilacak..." -ForegroundColor Yellow
                shutdown /r /t 10 /c "Lab yapilandirma sonrasi yeniden baslatma"
            }
            else {
                Write-Host "Lutfen daha sonra sistemi yeniden baslatin." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "║   " -NoNewline -ForegroundColor Red
        Write-Host "✗ YAPILANDIRMA TAMAMLANAMADI!" -NoNewline -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "   ║" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  ⚠  " -NoNewline -ForegroundColor Yellow
        Write-Host "Lutfen hatalari kontrol edin." -ForegroundColor Yellow
    }
    
    return $success
}

function New-LabGroup {
    param([string]$GroupName)

    if (Test-LocalGroupExists -GroupName $GroupName) {
        Write-Host "[BILGI] '$GroupName' grubu zaten mevcut." -ForegroundColor Yellow
        return $true
    }

    try {
        New-LocalGroup -Name $GroupName -Description "Lab $GroupName bilgisayarlari grubu" -ErrorAction Stop
        Write-Host "[BASARILI] '$GroupName' grubu olusturuldu." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[HATA] Grup olusturulamadi: $_" -ForegroundColor Red
        return $false
    }
}

function New-StudentUser {
    param([string]$UserName)

    if (Test-LocalUserExists -UserName $UserName) {
        Write-Host "[BILGI] '$UserName' kullanicisi zaten mevcut." -ForegroundColor Yellow
        return $true
    }

    try {
        # Sifresiz kullanici olustur
        New-LocalUser -Name $UserName `
                      -NoPassword `
                      -FullName "Ogrenci $UserName" `
                      -Description "Lab ogrenci hesabi" `
                      -ErrorAction Stop

        Write-Host "[BASARILI] '$UserName' kullanicisi olusturuldu (sifresiz)." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[HATA] Kullanici olusturulamadi: $_" -ForegroundColor Red
        return $false
    }
}

function Add-UserToLabGroup {
    param(
        [string]$UserName,
        [string]$GroupName
    )

    try {
        # Kullanici zaten grupta mi kontrol et
        $groupMembers = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue
        if ($groupMembers.Name -contains "$env:COMPUTERNAME\$UserName") {
            Write-Host "[BILGI] '$UserName' zaten '$GroupName' grubunda." -ForegroundColor Yellow
            return $true
        }

        Add-LocalGroupMember -Group $GroupName -Member $UserName -ErrorAction Stop
        Write-Host "[BASARILI] '$UserName' kullanicisi '$GroupName' grubuna eklendi." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[HATA] Kullanici gruba eklenemedi: $_" -ForegroundColor Red
        return $false
    }
}

function Set-ComputerNameSafely {
    param([string]$NewName)

    $currentName = $env:COMPUTERNAME

    if ($currentName -eq $NewName) {
        Write-Host "[BILGI] Bilgisayar adi zaten '$NewName'." -ForegroundColor Yellow
        return $true
    }

    try {
        Rename-Computer -NewName $NewName -Force -ErrorAction Stop | Out-Null
        Write-Host "[BASARILI] Bilgisayar adi '$NewName' olarak degistirildi." -ForegroundColor Green
        Write-Host "[ONEMLI] Degisikligin gecerli olmasi icin yeniden baslatma gerekiyor!" -ForegroundColor Magenta
        return $true
    }
    catch {
        Write-Host "[HATA] Bilgisayar adi degistirilemedi: $_" -ForegroundColor Red
        return $false
    }
}

function Remove-StudentUser {
    param([string]$UserName)

    # Guvenlik kontrolu: Sadece Ogrenci ile baslayan kullanicilar silinebilir
    if ($UserName -notmatch '^Ogrenci\d{2}$') {
        Write-Host "[HATA] Guvenlik: Sadece 'OgrenciXX' formatindaki kullanicilar silinebilir!" -ForegroundColor Red
        return $false
    }

    # Kullanici var mi kontrol et
    if (-not (Test-LocalUserExists -UserName $UserName)) {
        Write-Host "[HATA] '$UserName' kullanicisi bulunamadi!" -ForegroundColor Red
        return $false
    }

    # Kullanici profil yolu
    $userProfilePath = "C:\Users\$UserName"

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "SILINECEK BILGILER" -ForegroundColor White -BackgroundColor DarkYellow
    Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Kullanici adi : " -NoNewline -ForegroundColor White
    Write-Host "$UserName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Profil klasoru: " -NoNewline -ForegroundColor White
    Write-Host "$userProfilePath" -ForegroundColor Cyan
    Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "⚠ UYARI: " -NoNewline -ForegroundColor Red
    Write-Host "Bu islem geri alinamaz! Tum dosyalar silinecek!" -ForegroundColor Yellow
    Write-Host ""

    # Onay al
    $confirmation = Read-Host "Silme islemini onayliyor musunuz? (E/H)"
    if ($confirmation -notmatch '^[Ee]$') {
        Write-Host "Islem iptal edildi." -ForegroundColor Yellow
        return $false
    }

    try {
        # Kullaniciyi sil
        Remove-LocalUser -Name $UserName -ErrorAction Stop
        Write-Host "[BASARILI] '$UserName' kullanicisi silindi." -ForegroundColor Green

        # Profil klasorunu sil
        if (Test-Path $userProfilePath) {
            Write-Host "Profil klasoru siliniyor..." -ForegroundColor Cyan
            Remove-Item -Path $userProfilePath -Recurse -Force -ErrorAction Stop
            Write-Host "[BASARILI] Profil klasoru silindi: $userProfilePath" -ForegroundColor Green
        }
        else {
            Write-Host "[BILGI] Profil klasoru bulunamadi (zaten silinmis olabilir)." -ForegroundColor Yellow
        }

        return $true
    }
    catch {
        Write-Host "[HATA] Kullanici silinemedi: $_" -ForegroundColor Red
        return $false
    }
}

# ==============================
# ANA ISLEM FONKSIYONLARI
# ==============================

function Start-UserRemoval {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     " -NoNewline -ForegroundColor Cyan
    Write-Host "KULLANICI SILME" -NoNewline -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Ogrenci kullanicilarini listele
    $studentUsers = Get-StudentUsers

    if ($studentUsers.Count -eq 0) {
        Write-Host "  ⚠  " -NoNewline -ForegroundColor Yellow
        Write-Host "Silinebilecek ogrenci kullanicisi bulunamadi." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # Kullanicilari listele
    Write-Host "  ┌──────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "SILINEBILIR OGRENCI KULLANICILARI" -ForegroundColor White -BackgroundColor DarkYellow
    Write-Host "  │  " -ForegroundColor Yellow
    Write-Host "  └──────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    $index = 1
    $userList = @()
    foreach ($user in $studentUsers) {
        Write-Host "  " -NoNewline
        Write-Host "[$index]" -NoNewline -ForegroundColor Cyan
        Write-Host "  $($user.Name)" -ForegroundColor White
        $userList += $user.Name
        $index++
    }
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "[0]" -NoNewline -ForegroundColor Red
    Write-Host "  Iptal" -ForegroundColor DarkGray
    Write-Host ""

    # Kullanicidan secim al
    $maxIndex = $studentUsers.Count
    $choice = Get-ValidatedInput -Prompt "Silinecek kullaniciyi secin (0-$maxIndex)" -Min 0 -Max $maxIndex

    if ($choice -eq 0) {
        Write-Host "Islem iptal edildi." -ForegroundColor Yellow
        return
    }

    # Secilen kullaniciyi al
    $userName = $userList[$choice - 1]

    Write-Host ""
    Write-Host "Secilen kullanici: $userName" -ForegroundColor Cyan
    Write-Host ""

    # Silme islemini yap
    if (Remove-StudentUser -UserName $userName) {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "║     " -NoNewline -ForegroundColor Green
        Write-Host "✓ KULLANICI BASARIYLA SILINDI!" -NoNewline -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "     ║" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "║     " -NoNewline -ForegroundColor Red
        Write-Host "✗ SILME ISLEMI BASARISIZ!" -NoNewline -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "     ║" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
    }
}

function Start-LabConfiguration {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "YENI OGRENCI BILGISAYARI YAPILANDIRMA" -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # 1. Lab numarasi al (1-6)
    $labNumber = Get-ValidatedInput -Prompt "Ogrenci bilgisayari hangi labda? (1-6)" -Min 1 -Max 6

    # 2. Bilgisayar sirasi al (1-99)
    $computerNumber = Get-ValidatedInput -Prompt "Lab icindeki bilgisayar sirasi kac? (1-99)" -Min 1 -Max 99

    # 3. Isimleri turet
    $labNumberFormatted = Format-TwoDigit -Number $labNumber
    $computerNumberFormatted = Format-TwoDigit -Number $computerNumber

    $groupName = "LAB-$labNumberFormatted"
    $computerName = "LAB-$labNumberFormatted-BIL$computerNumberFormatted"
    $userName = "Ogrenci$computerNumberFormatted"

    # 4. Ozet goster
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "YAPILACAK ISLEMLER" -ForegroundColor White -BackgroundColor DarkYellow
    Write-Host "  ├─────────────────────────────────────────────┤" -ForegroundColor Yellow
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Grup adi        : " -NoNewline -ForegroundColor White
    Write-Host "$groupName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Bilgisayar adi  : " -NoNewline -ForegroundColor White
    Write-Host "$computerName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Kullanici adi   : " -NoNewline -ForegroundColor White
    Write-Host "$userName" -ForegroundColor Cyan
    Write-Host "  │  " -NoNewline -ForegroundColor Yellow
    Write-Host "Yetki seviyesi  : " -NoNewline -ForegroundColor White
    Write-Host "Administrator (Tam yetki)" -ForegroundColor Green
    Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""

    # 5. Onay al
    $confirmation = Read-Host "Devam etmek istiyor musunuz? (E/H)"
    if ($confirmation -notmatch '^[Ee]$') {
        Write-Host "Islem iptal edildi." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Islemler baslatiliyor..." -ForegroundColor Cyan
    Write-Host ""

    # 6. Islemleri yap
    $success = $true

    # Grup olustur
    if (-not (New-LabGroup -GroupName $groupName)) {
        $success = $false
    }

    # Kullanici olustur
    if (-not (New-StudentUser -UserName $userName)) {
        $success = $false
    }

    # Kullaniciyi LAB grubuna ekle
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName $groupName)) {
            $success = $false
        }
    }

    # Kullaniciyi Administrators grubuna ekle (admin yetkisi)
    if ($success) {
        if (-not (Add-UserToLabGroup -UserName $userName -GroupName "Administrators")) {
            $success = $false
        }
    }

    # Bilgisayar adini degistir
    if ($success) {
        if (-not (Set-ComputerNameSafely -NewName $computerName)) {
            $success = $false
        }
    }

    # 7. Sonuc
    Write-Host ""
    if ($success) {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "║     " -NoNewline -ForegroundColor Green
        Write-Host "✓ YAPILANDIRMA TAMAMLANDI!" -NoNewline -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "     ║" -ForegroundColor Green
        Write-Host "║                                        ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""

        # Restart gerekiyor mu kontrol et
        if ($env:COMPUTERNAME -ne $computerName) {
            Write-Host "ONEMLI: Bilgisayar adinin gecerli olmasi icin sistemi yeniden baslatmaniz gerekiyor." -ForegroundColor Magenta
            Write-Host ""
            $restart = Read-Host "Simdi yeniden baslatmak istiyor musunuz? (E/H)"
            if ($restart -match '^[Ee]$') {
                Write-Host "Sistem 10 saniye icinde yeniden baslatilacak..." -ForegroundColor Yellow
                shutdown /r /t 10 /c "Lab yapilandirma sonrasi yeniden baslatma"
            }
            else {
                Write-Host "Lutfen daha sonra sistemi yeniden baslatin." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "║   " -NoNewline -ForegroundColor Red
        Write-Host "✗ YAPILANDIRMA TAMAMLANAMADI!" -NoNewline -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "   ║" -ForegroundColor Red
        Write-Host "║                                        ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "  ⚠  " -NoNewline -ForegroundColor Yellow
        Write-Host "Lutfen hatalari kontrol edin." -ForegroundColor Yellow
    }
}

# ==============================
# ANA PROGRAM DONGUSU
# ==============================

function Start-Main {
    # Admin kontrolu
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "HATA: Bu script Administrator yetkisi ile calistirilmalidir!" -ForegroundColor Red
        Write-Host "PowerShell'i sag tiklayip 'Run as Administrator' ile acin." -ForegroundColor Yellow
        exit 1
    }

    # Ana dongu
    while ($true) {
        Show-Menu
        $choice = Read-Host "Seciminiz"

        switch ($choice) {
            "1" {
                Start-LabConfiguration
                Write-Host ""
                Read-Host "Devam etmek icin Enter'a basin"
            }
            "2" {
                Start-UserRemoval
                Write-Host ""
                Read-Host "Devam etmek icin Enter'a basin"
            }
            "3" {
                Export-ComputerInfo
                Write-Host ""
                Read-Host "Devam etmek icin Enter'a basin"
            }
            "4" {
                Import-AndConfigureFromCSV
                Write-Host ""
                Read-Host "Devam etmek icin Enter'a basin"
            }
            "5" {
                Start-QuickAutoConfigure
                Write-Host ""
                Read-Host "Devam etmek icin Enter'a basin"
            }
            "0" {
                Write-Host "Cikis yapiliyor..." -ForegroundColor Yellow
                exit 0
            }
            default {
                Write-Host "Gecersiz secim! Lutfen 1, 2, 3, 4, 5 veya 0 girin." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Script baslatildiginda ana fonksiyonu calistir
Start-Main
