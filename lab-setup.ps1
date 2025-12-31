#Requires -RunAsAdministrator

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
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   LAB BILGISAYAR YAPILANDIRMA ARACI   " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) Yeni ogrenci bilgisayari konfigure et" -ForegroundColor Yellow
    Write-Host "0) Cikis" -ForegroundColor Red
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
                      -UserMayNotChangePassword $false `
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
        Rename-Computer -NewName $NewName -Force -ErrorAction Stop
        Write-Host "[BASARILI] Bilgisayar adi '$NewName' olarak degistirildi." -ForegroundColor Green
        Write-Host "[ONEMLI] Degisikligin gecerli olmasi icin yeniden baslatma gerekiyor!" -ForegroundColor Magenta
        return $true
    }
    catch {
        Write-Host "[HATA] Bilgisayar adi degistirilemedi: $_" -ForegroundColor Red
        return $false
    }
}

# ==============================
# ANA ISLEM FONKSIYONU
# ==============================

function Start-LabConfiguration {
    Write-Host ""
    Write-Host "=== YENI OGRENCI BILGISAYARI YAPILANDIRMA ===" -ForegroundColor Cyan
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
    Write-Host "--- YAPILACAK ISLEMLER ---" -ForegroundColor Yellow
    Write-Host "Grup adi        : $groupName" -ForegroundColor White
    Write-Host "Bilgisayar adi  : $computerName" -ForegroundColor White
    Write-Host "Kullanici adi   : $userName" -ForegroundColor White
    Write-Host "Yetki seviyesi  : Administrator (Tam yetki)" -ForegroundColor Cyan
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
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "   YAPILANDIRMA TAMAMLANDI!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
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
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "   YAPILANDIRMA TAMAMLANAMADI!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
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
            "0" {
                Write-Host "Cikis yapiliyor..." -ForegroundColor Yellow
                exit 0
            }
            default {
                Write-Host "Gecersiz secim! Lutfen 1 veya 0 girin." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# Script baslatildiginda ana fonksiyonu calistir
Start-Main
