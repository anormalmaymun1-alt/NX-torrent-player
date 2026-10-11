# Devir: Akıntio, Aşama 1'den devam

Yeni bir oturuma bu dosyayla başlanır. Ayrıntılar `PLAN.md` dosyasında: inceleme sonuçları,
bağımlılık çakışmaları (D1–D7), modül sınırları, taşıma listesi, riskler (R1–R12)
ve onaylanan kararlar (§0, §11). Bu dosyada yazan kararları kullanıcıya yeniden sorma.

## Bağlam
- Repo: `anormalmaymun1-alt/NX-torrent-player`. Dal: `ccr-f8440549-75yhvj`.
- Bu repo, shodowlo/NX-torrent-player v0.5.0'ın (`38ef229`) birebir fork'u.
- Hedef: StreamFin'i (scamNscoot/StreamFin `5365f24`) ana proje yapmak; NXTP'nin torrent motorunu
  (`engine/`) ve hesap girişini modül olarak taşımak.
- Uygulama adı: **Akıntio**; dosya ve yol adlarında `Akintio`. Uygulamada "Stremio" adı ve logosu yok.
- `CLAUDE.md` NXTP'ye ait; birleşimden sonra güncellenecek.

## Teknik kararlar
- Portlib'ler StreamFin'in `scripts/switch/*/PKGBUILD` dosyalarından kendimiz derlenecek.
  - İmaj: `devkitpro/devkita64:20260219`.
  - Önce stok `switch-libmpv` kaldırılır.
  - `mbedtls libssh2 dav1d ffmpeg libuam` → `dkp-makepkg -siCf` ile derlenip kurulur.
  - `mpv curl` → `-sCf` ile derlenip `dkp-pacman -U` ile kurulur.
- mpv beslemesi `mpv_stream_cb` ile, `torrent://<infohash>/<fileIdx>` URI'si üzerinden.
  - `MPVCore` singleton olduğu için protokol bir kez kaydedilir.
  - `engine/stream.c` URI'den oturumu bulacak şekilde değişir.
  - Kapanış sırası: `torrentfs_cancel` → `mpv stop` → `torrentfs_close`.
- mbedTLS 3 uyumu: `engine/sha1_compat.h` (`dhtclient.c` içindeki `_ret` çağrıları).
- NXTP borealis yerel yaması 2 (TCP tamponları), StreamFin'in borealis `switch_wrapper.c` dosyasına taşınır.
- TLS doğrulaması açılır (`romfs:/cacert.pem`). StreamFin'in Google Analytics kodu kapatılır.
- authKey: `sdmc:/switch/Akintio/auth.key`. Çıkışta önce `/api/logout` çağrılır, sonra dosya silinir.
  Şifre hiçbir zaman diske veya loga yazılmaz.
- Lisans: `NOTICE` ve `THIRD_PARTY_LICENSES.md` oluşturulur, libutp MIT metni eklenir,
  README'de .nro'nun GPLv3 olduğu belirtilir.

## Ortam ve engeller
- Docker daemon kendiliğinden başlamıyor; `nohup dockerd > <log> 2>&1 &` ile elle başlatılmalı.
- **Engel 1:** Docker Hub, `devkitpro/devkita64:20260219` imajını çekerken **429 Too Many Requests**
  döndürdü.
- **Engel 2:** `pkg.devkitpro.org` proxy tarafından engelli (403), yani devkitPro doğrudan
  makineye de kurulamıyor.
- Bir Docker aynası (mirror.gcr.io) denenecekti; kullanıcı bu denemeyi reddetti.
- İlk adım: hangi yolun izleneceğini kullanıcıya sor:
  - Docker Hub'ı bir süre sonra yeniden denemek,
  - bir ayna kullanmak,
  - ağ ayarlarını değiştirmek (`read_documentation`, `environment.network`).
- Referans klonlar (StreamFin, upstream NXTP, stremio-core, switchfin, pacman-packages)
  önceki oturumun geçici alanındaydı; gerekirse yeniden klonla.

## Sıradaki iş: Aşama 1
1. `scripts/docker/Dockerfile`, `scripts/build-portlibs.sh` ve `scripts/build.sh` dosyalarını yaz.
2. StreamFin geçmişini `git merge --allow-unrelated-histories` ile birleştir.
   NXTP dosyalarını geçici olarak `legacy/nxtp/` altına taşı.
3. StreamFin'i olduğu gibi derle:
   `cmake -B build_switch -DPLATFORM_SWITCH=ON -DBUILTIN_NSP=OFF`, ardından `make StreamFin.nro`.

Sonra `PLAN.md` §10'daki sırayla Aşama 2 (hesap), 3 (torrent) ve 4 (arayüz) gelir.
Küçük commit'ler at. Her aşama sonunda neyin çalıştığını ve neyin cihaz testi gerektirdiğini yaz.
v0.1 bittiğinde main'e PR aç ve `subscribe_pr_activity` ile izlemeye al.
