# Akıntio: StreamFin + NX Torrent Player birleşimi, Aşama 0 inceleme ve yol haritası

**Akıntio** (dosya/yol adı: `Akintio`): Stremio addon protokolüyle çalışan,
hesap senkronizasyonlu ve torrent motorlu bir Nintendo Switch homebrew istemcisi.
Uygulama içinde "Stremio" adı ve logosu kullanılmayacak.

## 0. Alınan kararlar

| Konu | Karar |
|---|---|
| Ana proje | StreamFin (borealis + MPVCore + addon protokolü) |
| Repo | Bu repo (`anormalmaymun1-alt/NX-torrent-player`). StreamFin geçmişi `git merge --allow-unrelated-histories` ile alınır; iki projenin geçmişi ve atıfları korunur |
| Portlibs | StreamFin'in `scripts/switch/*/PKGBUILD` dosyalarından **kendimiz derleyeceğiz** (Docker içinde) |
| İsim | **Akıntio** / `Akintio` |
| mpv besleme | `mpv_stream_cb` (`torrent://` protokolü), yerel HTTP sunucusu değil (gerekçe §5) |

## 1. Kaynaklar ve doğrulama

| Kaynak | URL | İncelenen commit |
|---|---|---|
| StreamFin | https://github.com/scamNscoot/StreamFin | `5365f24` (v0.4.0 sonrası) |
| NX Torrent Player (upstream) | https://github.com/shodowlo/NX-torrent-player | `38ef229` (v0.5.0) |
| Bu repo (fork) | https://github.com/anormalmaymun1-alt/NX-torrent-player | `38ef229`: upstream ile birebir aynı (`diff -r` farksız) |
| Switchfin (StreamFin'in kökeni) | https://github.com/dragonflylee/switchfin | CI: `.github/workflows/build.yaml`, `switch-portlibs.yaml` |
| stremio-core | https://github.com/Stremio/stremio-core | `fa22c9c` (2026-10-08) |
| devkitPro portlibs | https://github.com/devkitPro/pacman-packages | `f103fe8` (2026-06-10) |

NX Torrent Player'ın upstream adresi tahminle bulunmadı. Bu repodaki
`CMakeLists.txt` dosyasında `UPDATE_REPO "shodowlo/NX-torrent-player"` yazıyor;
adresi klonlayıp içeriğin fork ile aynı olduğu doğrulandı.

## 2. Karşılaştırma tablosu

| | **StreamFin** | **NX Torrent Player (NXTP)** |
|---|---|---|
| Lisans | Apache-2.0 (`LICENSE`); Switchfin de Apache-2.0 (teyit edildi) | Apache-2.0 (`LICENSE`) |
| Build sistemi | CMake ≥3.18, borealis `toolchain.cmake`; `cmake -B build_switch -G Ninja -DPLATFORM_SWITCH=ON -DBUILTIN_NSP=OFF && ninja StreamFin.nro`. CI yok | CMake ≥3.15; `devkitpro/devkita64:latest` Docker + `st_build` volume |
| Platformlar | Switch, Linux/Win/macOS masaüstü (GLFW/SDL), PS4, Vita, Android | Yalnızca Switch (motor için `pctest/` PC derlemesi) |
| UI | borealis (xfangfang fork'u, gömülü) + lunasvg | borealis (xfangfang `5f08b28`, gömülü, 6 yerel yama: `library/borealis/VENDORED.md`) |
| Portlibs | **Switchfin özel**: mbedtls 3.6.5, curl 8.16.0 (mbedTLS), ffmpeg 7.1.5 (mbedtls TLS, libssh2, dav1d, nvtegra, `--enable-gpl --enable-version3`), libmpv 0.36.0 (GL + deko3d varyantları), dav1d 1.5.3, libssh2 1.11.1, libnx 4.12.0 | **devkitPro stok**: `switch-libmpv` 0.39.0, `switch-ffmpeg` 7.1 (libnx TLS, nvtegra), `switch-curl` 7.69.1 (`--with-default-ssl-backend=libnx`), `switch-mbedtls` 2.28.10, `switch-libwebp` 1.0.2 |
| Torrent | Yok. infoHash'li stream'ler "oynatılamaz" diye filtreleniyor; debrid şart | Kendi motoru (C): `engine/` (torrentfs, peer, swarm, udp_tracker, dht, magnet), gömülü libutp (MIT). Sadece indirir, seed etmez |
| mpv besleme | `MPVCore` singleton (`app/src/view/mpv_core.cpp`), `loadfile <url>` ile doğrudan HTTP(S) | `mpv_stream_cb_add_ro(mpv, "torrent", …)` (`engine/stream.c`), `loadfile torrent://stream`; her oynatmada yeni `mpv_create` |
| Stremio API | Yalnızca addon protokolü: düz GET `{addon}/stream/{type}/{id}.json`, Cinemeta katalog/meta, altyazı addonu. Addon URL'leri `sdmc:/switch/streamfin-addon.txt` dosyasından. **Hesap yok** | `api.strem.io/api/{login, datastoreGet, datastorePut, addonCollectionGet}` (`app/stremio.cpp`), elle yazılmış string tarayan JSON (`app/json.cpp`) |
| HTTP/TLS | `app/src/api/http.cpp` içinde **`SSL_VERIFYPEER=0`, `VERIFYHOST=0`** | `app/http.cpp`: `CURLOPT_CAINFO=romfs:/cacert.pem`, doğrulama açık |
| JSON | nlohmann/json (borealis içinden) | Kendi minimal ayrıştırıcısı |
| Yerel takip | `resume.json` (Continue Watching), favoriler: yerel | Hesap kütüphanesi + `datastorePut` ile izleme durumu |
| Telemetri | **Google Analytics açık** (`app/src/api/analytics.cpp`, Switchfin'in GA anahtarı, `main.cpp` içinden çağrılıyor) | Yok |
| Applet modu | Uyarı yok (borealis wrapper: 2 BSD oturumu) | `appletModeBlock()` (`app/main.cpp:923`): uygulama açılmayı reddeder |
| Soket ayarı | borealis wrapper: 12 oturum, `sb_efficiency=8`, TCP tamponları varsayılan | Aynısı + **yerel yama**: başlangıç TCP tamponları 16/32 KB (ENOBUFS'u çözüyor) |

## 3. Stremio hesap API'si (NXTP kodu + stremio-core ile teyitli)

Taban adres: `https://api.strem.io/api/` (stremio-core `src/constants.rs`:
`API_URL`). Hepsi `POST` ve JSON gövdeli. Yanıt zarfı `{"result": …}` ya da
`{"error": {"message", "code"}}` (`src/types/api/response.rs`: `APIResult`).

| İşlem | Yol | Gövde (stremio-core alan adları) | NXTP'de |
|---|---|---|---|
| Giriş | `login` | `{"type":"Login","email","password","facebook":false}` (`AuthRequest::Login`) → `result.authKey`, `result.user` | `loginAsync` (`app/stremio.cpp:576`). HTTP 200 dönüp `error` içerebiliyor, NXTP bunu dikkate alıyor |
| Çıkış | `logout` | `{"type":"Logout","authKey"}` | **Çağrılmıyor**: NXTP yalnızca yerel anahtar dosyasını siliyor (`clearAuthKey`) |
| Addon listesi | `addonCollectionGet` | `{"type":"AddonCollectionGet","authKey","update":true}` → `result.addons[]` (Descriptor: `transportUrl`, `manifest`), `lastModified` | `fetchAddonsAsync` (`:1342`) |
| Kullanıcı | `getUser` | `{"type":"GetUser","authKey"}` | Yok (gerekirse) |
| Kütüphane okuma | `datastoreGet` | `{"authKey","collection":"libraryItem","ids":[…],"all":bool}` | `fetchLibraryAsync` (`all:true`), tekil okuma (`ids`) |
| Kütüphane yazma | `datastorePut` | `{"authKey","collection":"libraryItem","changes":[LibraryItem…]}` | add/remove/izleme durumu. **Oku-değiştir-yaz** yapılıyor çünkü put tüm öğeyi değiştiriyor |
| Meta | `datastoreMeta` | `{"authKey","collection"}` | Yok (artımlı senkronizasyon için ileride) |
| QR/link ile giriş (opsiyonel) | `GET https://link.stremio.com/api/v2/create` ve `v2/read?code=` | `LinkRequest::{Create, Read}` → `code`, `link`, `qrcode` / `authKey` | Yok. Konsolda şifre yazmadan giriş imkânı verir. Tam yol (`/api` öneki) Aşama 2'de `fetch_api.rs` üzerinden doğrulanacak |

**LibraryItem** (`src/types/library/library_item.rs`): `_id`, `name`, `type`,
`poster`, `posterShape`, `removed`, `temp`, `_ctime`, `_mtime`, `state`,
`behaviorHints`. **state**: `lastWatched`, `timeWatched`, `timeOffset`,
`overallTimeWatched`, `timesWatched`, `flaggedWatched`, `duration`,
`video_id` (alt çizgili), `watched`, `noNotif`. Zaman alanları milisaniye.

**Stream (torrent)** (`src/types/resource/stream.rs`, `StreamSource::Torrent`):
`infoHash` (40 hex), `fileIdx` (opsiyonel), `announce` (alias `sources`),
`fileMustInclude`. `behaviorHints`: `notWebReady`, `bingeGroup`, `filename`,
`videoSize`, `videoHash`, `proxyHeaders`, `countryWhitelist`.

## 4. Bağımlılık çakışmaları ve çözüm

| # | Çakışma | Etki | Çözüm |
|---|---|---|---|
| D1 | mbedTLS 2.28 (NXTP) ↔ 3.6.5 (StreamFin) | `engine/dhtclient.c` `mbedtls_sha1_{starts,update,finish}_ret` kullanıyor; bunlar **3.x'te kaldırıldı**. `peer.c`/`swarm.c`/`torrent.c` içindeki tek seferlik `mbedtls_sha1()` 3.x'te de var | `engine/sha1_compat.h`: 3.x'te `_ret`'siz adlar. Motor mantığına dokunulmaz |
| D2 | curl 7.69 (libnx SSL) ↔ curl 8.16 (mbedTLS) | NXTP `CURLOPT_CAINFO` dosya yolu kullanıyor, mbedTLS arka ucunda da çalışır. `engine/torrent.c` tracker announce'ları (bilinçli olarak doğrulamasız) değişmez | StreamFin'in `http.cpp` dosyasına NXTP'nin `verifyTls()` yaklaşımı taşınır (`romfs:/cacert.pem` + doğrulama açık) |
| D3 | libmpv 0.39 ↔ 0.36 | `mpv_stream_cb_add_ro` / `stream_cb.h` her ikisinde de var (0.28'den beri). NXTP'nin oynatıcısı taşınmayacağı için başka mpv API farkı önemli değil | Değişiklik gerekmiyor; Aşama 3'te derlenip doğrulanacak |
| D4 | İki farklı borealis kopyası | NXTP'nin 6 yerel yaması StreamFin'in kopyasında yok | Yalnızca **yama 2 (TCP tamponları, ENOBUFS)** StreamFin'in `library/borealis/library/lib/platforms/switch/switch_wrapper.c` dosyasına taşınır. 1, 3–6 kozmetik, alınmaz. `VENDORED.md` StreamFin borealis'i için yeniden yazılır |
| D5 | libwebp | StreamFin `pkg_search_module(libwebp QUIET)` → `USE_WEBP`; stok `switch-libwebp` imajda var | Değişiklik yok |
| D6 | Docker imajı | StreamFin'in `Dockerfile`'ı `devkita64:20241023`, Switchfin CI'ı `20260219` kullanıyor; stok `switch-libmpv` kaldırılmalı | §6 Aşama 1: sabit etiketli imaj + PKGBUILD derlemesi |
| D7 | `CLAUDE.md` "curl 7.69/mbedTLS" diyor, devkitPro PKGBUILD'i libnx SSL arka ucunu gösteriyor | Belge tutarsız. Birleşimden sonra curl 8.x/mbedTLS olacak | `CLAUDE.md` Aşama 1'de güncellenir |

Kendi derleyeceğimiz portlib seti (StreamFin `scripts/switch`, sürümler aynen):
mbedtls 3.6.5-1, libssh2 1.11.1-1, dav1d 1.5.3-1, ffmpeg 7.1.5-5, libuam
(deko3d varyantı için), mpv 0.36.0-5, curl 8.16.0-2. Sıra Switchfin CI'ındaki
gibi: `mbedtls libssh2 dav1d ffmpeg libuam` derlenip kurulur (`-si`), ardından
`mpv curl`. Sürüm değişikliği yapılmayacak; gerekirse önce size sorulacak.

## 5. Modül sınırları ve mimari

```
app/src/api/stremio.hpp            (StreamFin) addon protokolü: Stream'e fileIdx/sources/behaviorHints eklenir
app/src/api/account/               (YENİ) hesap modülü, UI'dan bağımsız, masaüstü build'de test edilebilir
    account_api.{hpp,cpp}          login/logout/getUser/addonCollectionGet/datastoreGet/datastorePut (nlohmann)
    auth_store.{hpp,cpp}           authKey'i SD'de saklama/silme (şifre asla yazılmaz)
    library_sync.{hpp,cpp}         LibraryItem oku-değiştir-yaz, izleme durumu itme
app/src/torrent/                   (YENİ) motor ile UI arasındaki köprü (C++)
    torrent_session.{hpp,cpp}      infoHash+fileIdx+sources → magnet; torrentfs aç/kapat; istatistik anlık görüntüsü
engine/                            (NXTP'den aynen) C motoru + libutp; stream.c oturum kaydına uyarlanır
include/libutp/                    (NXTP include/) libutp başlıkları
app/src/activity/…                 (StreamFin) UI: giriş ekranı, stream listesi, oynatıcı paneli
```

**mpv besleme kararı: `stream_cb`.**
- NXTP'de cihazda kanıtlandı. Ek soket yok. Seek doğrudan
  `torrentfs_set_playhead`'e iniyor.
- Yerel HTTP sunucusu kullanılsaydı her bağlantı 1 BSD oturumu ve soket tampon
  havuzundan pay alırdı. Bu havuz peer'larla zaten yarışıyor (ENOBUFS). Ayrıca
  Range/keep-alive işini kendimiz yazmamız gerekirdi.
- StreamFin'in `MPVCore`'u singleton olduğu için `torrent://` protokolü
  **bir kez** `MPVCore::init` içinde kaydedilir. `stream.c`'deki `open_cb` şu an
  URI'yi yok sayıp sabit `tfs` kullanıyor. Bu, `torrent://<infohash>/<fileIdx>`
  URI'sinden etkin oturumu bulacak şekilde değişecek.
- Kapanış sırası: önce `torrentfs_cancel` (bloklu `read`'i çözer), sonra
  `mpv stop`, en son `torrentfs_close`. NXTP'deki `aebfaa4` "Fix freeze when
  exiting torrent" dersi.

**Stream seçimi:** `url` varsa mevcut yol (`RemoteView::play(url)`) kullanılır.
`infoHash` varsa `TorrentSession::open(hash, fileIdx, sources)` çağrılır,
ardından `play("torrent://…")`. Yalnızca `notWebReady` olan HTTP stream'leri de
mpv'ye doğrudan verilir.

## 6. Dosya bazında taşıma listesi

### NXTP'den Akıntio'ya

| Kaynak (NXTP) | Hedef | Nasıl |
|---|---|---|
| `engine/*.c,*.h`, `engine/utp*.cpp` | `engine/` | Aynen. `dhtclient.c` için D1 shim |
| `include/*.h` (libutp) | `include/libutp/` | Aynen. libutp MIT lisans metni eklenir (şu an repoda yok) |
| `engine/stream.c` | `engine/stream.c` | URI → oturum çözümleme (§5) |
| `pctest/` | `pctest/` | Aynen. mbedTLS 3 için güncellenir (host motor testi) |
| `app/stremio.cpp`: `loginAsync`, `fetchLibraryAsync`, `setLibraryMemberAsync`, `clearWatchStateAsync`, `pushWatchStateAsync`, `fetchAddonsAsync`, `newLibraryItem`, `setField`, authKey dosya fonksiyonları | `app/src/api/account/*` | **Mantık referans alınır, nlohmann ile yeniden yazılır.** NXTP'nin string tarayan JSON'u taşınmaz |
| `app/browse.cpp`: `kPublicTrackers`, magnet kurma, 4K tespiti | `app/src/torrent/torrent_session.cpp`, `stremio.hpp` | Fonksiyon düzeyinde taşınır |
| `app/http.cpp`: `verifyTls` | `app/src/api/http.cpp` | Doğrulama açılır (D2) |
| `assets/cacert.pem` | `resources/cacert.pem` | Aynen (romfs'e girer) |
| `app/main.cpp`: `appletModeBlock` | `app/src/main.cpp` | **Uyarıya dönüştürülür** (§8 Bellek) |
| `app/player.cpp`: istatistik paneli, `torrentfs_set_backlog` beslemesi, yükleme/tampon mantığı | StreamFin `video_view` / `player_view` | Referans alınarak yeniden yazılır (UI farklı) |
| `app/config.cpp`: `ramStream`, governor, 4K gizleme | StreamFin `utils/config.cpp` anahtarları | Yeni ayar anahtarları |
| borealis yaması 2 (`switch_wrapper.c`) | StreamFin borealis'i | §4 D4 |

**Taşınmayacaklar:** NXTP'nin UI'ı (`main.cpp` sekmeleri, `browse.cpp`,
`settings.cpp`, `theme`, `i18n`), güncelleyici (`update.cpp`, ileride
düşünülebilir), yerel torrent/magnet sekmesi (opsiyonel, Aşama 4 sonrası),
"Stremio" marka varlıkları (`assets/stremio-icon.png`, `stremio.svg`,
`NX-torrent-player-stremio.png`).

### StreamFin'de değişecekler

- `app/include/api/stremio.hpp`: `Stream` yapısına `fileIdx`, `sources`,
  `behaviorHints` alanları eklenir. `getStreams` tekilleştirmesi torrentler için
  `infoHash+fileIdx` ile yapılır. `STREAM_ADDONS`, metin dosyasına ek olarak
  hesaptan gelen `addonCollectionGet` addon'larıyla da doldurulur (`stream`
  kaynağı sunanlar; manifest `resources` alanı string ya da nesne olabilir).
- `app/src/activity/stremio_streams.cpp`: `url` filtresi kaldırılır, torrent
  satırları gösterilir, `onItemSelected` iki yola ayrılır.
- `stremio_favourites` / `stremio_resume`: hesap girişi varsa hesap
  kütüphanesiyle senkronize olur, yoksa bugünkü yerel davranış sürer.
- `app/src/api/analytics.cpp` + çağrı yerleri: **Google Analytics tamamen
  devre dışı** (Switchfin'in GA anahtarına veri gidiyor).
- `CMakeLists.txt`: proje adı `Akintio`, NACP başlığı "Akıntio", yeni Title ID,
  `engine/` kaynakları + `-DPOSIX`, mbedtls bağlantısı, romfs'e `cacert.pem`.
- Marka: UI metinlerinden "Stremio" ve "StreamFin" kaldırılır. Yollar
  `sdmc:/switch/Akintio/` ve `sdmc:/config/Akintio/` olur.
- Jellyfin'e özgü kod (sunucu listesi, webdav, danmaku…) ilk aşamalarda
  **silinmez** (riskli ve gereksiz). Temizlik ayrı bir aşamada yapılır.

## 7. Lisans

- StreamFin, Switchfin, NXTP ve borealis **Apache-2.0**, lunasvg ve libutp
  **MIT**. Kaynak düzeyinde çakışma yok: Apache-2.0 kodu Apache-2.0 bir projeye
  alınabilir.
- Apache-2.0 §4 yükümlülükleri: `LICENSE` korunur, mevcut telif başlıkları
  korunur, **değiştirilen dosyalara "değiştirildi" notu** eklenir, borealis'in
  `NOTICE` dosyası dağıtımla birlikte verilir. Kökte bir `NOTICE` ve bir
  `THIRD_PARTY_LICENSES.md` oluşturulur (Switchfin/dragonflylee, StreamFin/
  scamNscoot, NXTP/shodowlo, borealis, lunasvg, libutp MIT, nlohmann MIT,
  Mozilla CA bundle MPL-2.0).
- **İkili dosya (.nro) GPL'dir:** ffmpeg `--enable-gpl --enable-version3` ile,
  mpv de varsayılan GPL yapılandırmasıyla derleniyor ve statik bağlanıyor.
  Dağıtılan .nro birleşik bir eser olarak **GPLv3** koşullarına tabidir.
  Apache-2.0 GPLv3 ile uyumludur, GPLv2 ile değil; `version3` seçeneği bu yüzden
  işimize yarıyor. Sonuç: her .nro sürümüyle birlikte tam kaynak (bu repo +
  portlib PKGBUILD/yamaları) erişilebilir olmalı. Repo açık olduğu sürece bu
  sağlanıyor; README'de belirtilecek. (Hukuki tavsiye değildir.)
- Marka: Uygulamada "Stremio" adı ve logosu olmayacak. README'de yalnızca
  "Stremio addon protokolüyle uyumlu" ifadesi ve "bağlantılı değildir" notu yer
  alacak.

## 8. Riskler

| Risk | Açıklama | Önlem |
|---|---|---|
| R1 Portlib derlemesi | ffmpeg/mpv derlemesi uzun (~1 saat). Kaynak tarball'ları (`ffmpeg.org`, `curl.se`, `videolan`) taşınabilir ya da silinebilir | Derlenmiş `.pkg.tar.zst`'ler ve kaynak tarball'ları kendi GitHub release'imize konur, sha256'lar betikte sabitlenir |
| R2 SD ↔ RAM önbellek | Sizin kısıtınız "önbellek SD'de, RAM küçük". NXTP yazarı ise SD'ye parça yazmanın FAT servisini kilitleyip takılmaya yol açtığını ölçtü ve **RAM modunu varsayılan yaptı** | Varsayılan **SD (parçalı, 4 GB FAT32 sınırına uygun)**, "RAM akış modu" ayar olarak kalır. Cihaz testinden sonra yeniden değerlendirilir |
| R3 Soket havuzu | StreamFin poster/katalog indirmelerini paralel yapıyor; mpv HTTP + peer'lar aynı BSD oturum (12) ve tampon havuzunu paylaşıyor | D4 yaması. Oynatma sırasında görsel indirmeleri durdurmak. İstatistik panelindeki `sock fail` sayacı izlenir |
| R4 Bellek | mpv demuxer önbelleği (StreamFin varsayılan 100 MB) + motor penceresi + borealis | Torrent oynatmada demuxer sınırı `loadfile` seçenekleriyle ayarlanır. Applet modunda torrent kapatılır |
| R5 Applet modu | Applet modunda wrapper 2 BSD oturumu ve `sb_efficiency=1` veriyor, torrent pratikte çalışmaz | Açılışta **uyarı diyaloğu** gösterilir, HTTP stream'ler çalışır, torrent kaynakları "tam RAM gerekli" diye işaretlenir. Switchfin'in `BUILTIN_NSP` forwarder seçeneği değerlendirilir |
| R6 TLS | StreamFin doğrulamayı kapatmış. Açınca cihaz saati yanlışsa sertifika hatası çıkar | Hata mesajında "konsol saatini kontrol edin" yazar (NXTP deneyimi) |
| R7 Kapanışta donma | Bloklu `read` + mpv singleton | §5 kapanış sırası. Cihazda "oynat → geri çık" döngüsü test edilir |
| R8 datastorePut | Öğenin tamamını değiştiriyor. Başka cihazla çakışma olabilir (`_mtime`) | Oku-değiştir-yaz (NXTP gibi), bilinmeyen alanlar korunur |
| R9 Addon çeşitliliği | `sources` girdilerinin biçimi (ör. `tracker:`/`dht:` öneki olup olmadığı) **gerçek yanıtla doğrulanacak**. Manifest `resources` string/nesne karışık | Toleranslı ayrıştırma, birim testleri kaydedilmiş yanıtlarla |
| R10 Gizlilik | Switchfin'den gelen GA telemetrisi | İlk kod commit'lerinde kapatılır |
| R11 Masaüstü build | StreamFin masaüstünde derleniyor ama motor `switch.h`'ye bağımlı (`pctest/compat` shim'i var) | Hesap modülü masaüstünde, motor `pctest` ile test edilir |
| R12 Cihazda test | Burada Switch yok; ağ politikası peer bağlantısına (UDP/BT) büyük olasılıkla izin vermiyor | Her aşama sonunda "test edilemedi" listesi; cihaz geri bildirimi |

## 9. Güvenlik

- Şifre yalnızca RAM'de tutulur ve login isteğinden hemen sonra silinir. Diske,
  loga ya da yapılandırma dosyasına yazılmaz. HTTP loglarında istek gövdeleri
  yazdırılmaz.
- authKey `sdmc:/switch/Akintio/auth.key` dosyasında saklanır. Çıkışta önce
  `logout` API'si çağrılır (anahtar sunucuda geçersiz olur), sonra dosya silinir.
  Ağ yoksa dosya yine silinir.
- E-posta, hesap ekranında göstermek için ayrı dosyada tutulur (NXTP gibi).
  İstenirse bu da kaldırılabilir.
- QR/link girişi (opsiyonel) konsolda şifre yazmayı tamamen ortadan kaldırır.

## 10. Yol haritası

Her aşama küçük commit'lerle ilerler. Aşama sonunda neyin çalıştığını ve neyin
cihaz gerektirdiğini yazarım.

**Aşama 1: Tekrarlanabilir build**
1. `scripts/docker/Dockerfile` (`devkitpro/devkita64:20260219` sabit) +
   `scripts/build-portlibs.sh` (StreamFin PKGBUILD'leri, Switchfin CI'ındaki
   sıra, stok `switch-libmpv` kaldırılır) + `scripts/build.sh` (nro).
2. StreamFin geçmişini bu repoya birleştirme: StreamFin ağacı köke gelir, NXTP
   dosyaları geçici olarak `legacy/nxtp/` altına taşınır (sonraki aşamalarda
   parça parça alınır, en sonda silinir).
3. StreamFin'i **olduğu gibi** derleyip `.nro` üretmek.
   *Burada test edilebilir:* derleme. *Cihaz:* .nro açılıyor mu, HTTP stream
   oynuyor mu.

**Aşama 2: Hesap modülü**
`account/` modülü (nlohmann), auth store, logout, addon koleksiyonu →
`STREAM_ADDONS`, kütüphane oku/yaz, izleme durumu. Masaüstü build'de ve
kaydedilmiş JSON yanıtlarıyla birim testi. Gerçek hesapla giriş testi sizde.

**Aşama 3: Torrent modülü**
Motor + sha1 shim, `pctest` host derlemesi, `torrent_session`, `stream.c`
uyarlaması, stream listesinde infoHash yönlendirme, D4 soket yaması, oynatıcı
istatistik paneli (peer, hız, tampon, parça). *Cihaz:* gerçek akış, seek,
çıkışta donma, ENOBUFS.

**Aşama 4: Arayüz ve ayarlar**
Giriş ekranı (+ opsiyonel QR), torrent kaynak rozetleri, ayarlar (önbellek
konumu/boyutu, RAM modu, 4K filtresi), applet uyarısı, yeniden adlandırma ve
marka temizliği, GA kaldırma (Aşama 1–2'de erken yapılabilir), lisans ekranı +
`NOTICE`/`THIRD_PARTY_LICENSES.md`, `CLAUDE.md`/README güncellemesi.

## 11. Onayınızı bekleyen noktalar

1. R2: önbellek varsayılanının **SD** olması (NXTP yazarının RAM önerisine rağmen).
2. Applet modunda NXTP gibi tamamen bloklamak yerine **uyarı + yalnızca HTTP**.
3. Aşama 1'de NXTP dosyalarının geçici olarak `legacy/nxtp/` altına taşınması.
4. QR/link ile girişin Aşama 4'e eklenmesi.
