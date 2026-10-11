# Devir: Akıntio, Aşama 1'den devam

Yeni bir oturuma bu dosyayla başlanır. Ayrıntılar `PLAN.md` dosyasında: inceleme sonuçları,
bağımlılık çakışmaları (D1–D7), modül sınırları, taşıma listesi, riskler (R1–R12)
ve onaylanan kararlar (§0, §11). Bu dosyada yazan kararları kullanıcıya yeniden sorma.

## Bağlam
- Repo: `anormalmaymun1-alt/NX-torrent-player`. Dal: `ccr-f8440549-75yhvj`.
- Bu dosyayı okuduktan sonra ilk iş: `dockerd`'yi başlat, `scripts/build.sh`'yi yukarıdaki ortam değişkenleriyle çalıştır.
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
- Docker Hub anonim çekimde **429** veriyor (2. oturumda da tekrarlandı). Kullanıcının kararı:
  **Docker Hub girişi**. Ortama `DOCKERHUB_USER` ve `DOCKERHUB_TOKEN` (salt okunur erişim belirteci)
  eklenecek; `scripts/build.sh` bunlar varsa `docker login` yapıyor. Ayna kullanılmıyor.
- `pkg.devkitpro.org` proxy tarafından engelli (403). `dkp-makepkg -s` eksik bağımlılık için oraya
  gitmeye çalışırsa takılır; imajda önceden kurulu olmaları bekleniyor (doğrulanmadı).
- Konteyner içinden proxy'ye `127.0.0.1` üzerinden erişmek için `--network host` gerekiyor ve
  proxy CA'sı güvenilir yapılmalı (`/root/.ccr/README.md`). Bu ortamda derleme komutu:
  `DOCKER_ARGS="--network host" EXTRA_CA_CERT=/root/.ccr/ca-bundle.crt scripts/build.sh`
- Kaynak tarball'ları: curl, dav1d, ffmpeg, libssh2 ve mbedtls (GitHub release) iniyor.
  GitHub `/archive/` adresleri (mpv, libuam) 403 veriyor; `build-portlibs.sh` bunları git klonundan
  `git archive | gzip -n` ile yeniden üretiyor. mpv 0.36.0 için sha256 PKGBUILD'dekiyle aynı çıktı.
- Push dalı: kullanıcının kararıyla `ccr-f8440549-75yhvj` (oturumun atadığı dal farklı olsa da).
- Referans klonlar geçici alandadır; gerekirse yeniden klonla.

## Aşama 1 durumu
1. ✅ `scripts/docker/Dockerfile`, `scripts/build-portlibs.sh`, `scripts/build.sh` yazıldı
   (henüz imaj olmadığı için çalıştırılmadı; yalnızca `bash -n` ve prefetch geri dönüşü test edildi).
2. ✅ NXTP `legacy/nxtp/` altına taşındı, StreamFin `5365f24` `--allow-unrelated-histories` ile birleşti.
3. ⏳ Derleme: imaj çekilince `scripts/build.sh` çalıştırılacak (hedef `StreamFin.nro`).
   Not: Switchfin CI artık mbedtls 3.6.7 / curl 8.21.0 / dav1d 1.5.4 kullanıyor; biz kararlaştırıldığı
   gibi StreamFin PKGBUILD sürümlerinde (3.6.5 / 8.16.0 / 1.5.3) kalıyoruz.

Sonra `PLAN.md` §10'daki sırayla Aşama 2 (hesap), 3 (torrent) ve 4 (arayüz) gelir.
Küçük commit'ler at. Her aşama sonunda neyin çalıştığını ve neyin cihaz testi gerektirdiğini yaz.
v0.1 bittiğinde main'e PR aç ve `subscribe_pr_activity` ile izlemeye al.
