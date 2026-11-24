# Mencatat Hardware ID dari Windows (tanpa flashdisk)

Untuk Tahap 6 (DESIGN §25): sebelum Windows bawaan Zyrex dihapus, catat chip **Wi-Fi**, **suara**, dan **Bluetooth**-nya. Dari ID ini bisa dicek apakah Debian 13 punya driver dan firmware-nya, **sebelum** apa pun dihapus. Tidak ada yang diubah di laptop.

## Cara 1: PowerShell (paling cepat)

1. Klik kanan tombol **Start** → **Terminal** (atau **Windows PowerShell**). Tidak perlu admin.
2. Tempel perintah ini, lalu Enter:

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.Class -in 'Net','MEDIA','AudioEndpoint','Bluetooth','Camera','Image','Display','Mouse','HIDClass','Battery','System' -and $_.InstanceId -match '^(PCI|USB|ACPI|HDAUDIO|INTELAUDIO)' } |
  Sort-Object Class, FriendlyName |
  Format-Table Class, FriendlyName, InstanceId -AutoSize -Wrap |
  Out-File -Width 300 "$env:USERPROFILE\Desktop\zyrex-hardware-id.txt"
```

3. File **`zyrex-hardware-id.txt`** muncul di Desktop. Kirim file itu.

## Cara 2: Device Manager (manual)

1. Klik kanan **Start** → **Device Manager**.
2. Buka **Network adapters**, klik ganda kartu **Wi-Fi** (biasanya "Intel … Wireless" atau "Realtek … Wireless") → tab **Details** → pilih **Hardware Ids** → catat baris pertama, misalnya `PCI\VEN_8086&DEV_31DC&SUBSYS_…`.
3. Ulangi untuk:
   - **Sound, video and game controllers**: semua baris (perangkat suara);
   - **Bluetooth**: adaptornya;
   - **Cameras** / **Imaging devices**: kamera;
   - **Display adapters**: kartu grafis;
   - **Mice and other pointing devices** / **Human Interface Devices**: touchpad.

## Yang paling penting

| Perangkat | Kenapa |
|---|---|
| Wi-Fi | tanpa driver/firmware, Atlas OS tidak bisa online |
| Suara (terutama "Intel Smart Sound Technology" / "SST") | bila ada, Debian butuh paket `firmware-sof-signed` supaya speaker & mikrofon bekerja |
| Touchpad (I2C HID) | supaya mouse bawaan langsung jalan |

Catatan: hanya perangkat di dalam laptop yang dicatat; HP atau earphone Bluetooth yang pernah dipasangkan (nama & alamatnya) sengaja tidak ikut.
