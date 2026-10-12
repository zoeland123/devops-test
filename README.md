# Hello DevOps

Aplikasi HTTP sederhana dengan Go untuk latihan build image Docker, hotfix binary,
dan pipeline CI/CD Jenkins.

## Persyaratan

- Go 1.22 atau lebih baru untuk menjalankan dan menguji aplikasi secara lokal.
- Docker untuk membangun dan menjalankan image.
- Jenkins dengan Git, Pipeline, dan Credentials Binding plugins untuk pipeline.
- Agent Jenkins memiliki Go, Docker CLI, akses ke Docker daemon, dan `curl`.

## Part I: Build dan jalankan

Jalankan unit test dan static analysis:

```sh
go vet ./...
go test ./...
```

Untuk menjalankan aplikasi langsung dengan Go:

```sh
go run .
```

Aplikasi mendengarkan port `8080` secara default. Verifikasi dari terminal lain:

```sh
curl http://localhost:8080/
```

Respons default: `Hello, DevOps! version=dev`.

Build image versi `1.0.0` dan jalankan container:

```sh
docker build --build-arg VERSION=1.0.0 -t hello-devops:1.0.0 .
docker run -d --name app -p 8081:8080 --restart unless-stopped hello-devops:1.0.0
curl http://localhost:8081/
```

Respons yang diharapkan: `Hello, DevOps! version=1.0.0`.
Jika nama `app` sudah digunakan container lain, pilih nama container dan port
host yang belum digunakan, lalu sesuaikan perintah deploy.

Dockerfile menggunakan multi-stage build: Go mengompilasi binary statis dengan
`CGO_ENABLED=0`, lalu binary saja disalin ke image final `scratch`. Ini menjaga
image kecil dan mengurangi komponen runtime, dengan trade-off tidak ada shell
untuk debugging di dalam container. Hasil pengukuran yang tercatat untuk image
`hello-devops:1.0.0` adalah **6.86 MB** ukuran image dan **2.09 MB** content size;
ukuran dapat berbeda pada build lain.

## Part II: Hotfix dan rollback

Container dijalankan dengan restart policy otomatis. Perintah berikut
memetakan host port `8080` ke port aplikasi `8080` di container:

```sh
docker run -d --name app -p 8080:8080 --restart unless-stopped hello-devops:1.0.0
curl http://localhost:8080/
```

Output sebelum swap:

```text
Hello, DevOps! version=1.0.0
```

Untuk hotfix, binary Linux baru dibangun terpisah memakai Go builder container
dan workspace yang di-mount. Ini tidak membangun ulang image aplikasi dan tidak
menghapus container `app`. Jalankan dari root repository:

```sh
docker run --rm -v "$(pwd):/src" -w /src golang:1.22-alpine \
	go build -trimpath -ldflags="-s -w -X main.version=1.0.1" -o app-new .
docker cp ./app-new app:/app
docker restart app
curl http://localhost:8080/
```

Output sesudah swap:

```text
Hello, DevOps! version=1.0.1
```

Pendekatan ini cocok untuk hotfix darurat karena hanya binary yang disalin dan
proses container yang direstart; port mapping, volume, dan konfigurasi container
tetap ada, tanpa menjalankan ulang `docker build`. Log pengujian yang tersimpan
menunjukkan versi berubah dari `1.0.0` ke `1.0.1` pada host port `8081` dan
container tetap hidup setelah restart. Trade-off-nya adalah *image drift*:
binary di container berbeda dari image asal. Restart menyebabkan jeda singkat;
catatan pengujian tidak mengukur downtime secara presisi.

Pipeline menggunakan `scripts/deploy.sh` untuk proses yang sama. Script itu
membuat container sementara dari image baru, menyalin `/app`, menyimpan backup
binary lama, menyalin binary baru ke container target, lalu restart. Script
memeriksa `HEALTH_URL` (default `http://host.docker.internal:8080/`) sampai lima
kali. Jika health check gagal, script menyalin kembali backup dan me-restart
container. Rollback ini hanya berlaku setelah backup berhasil dibuat; kegagalan
sebelumnya, misalnya container target tidak ditemukan, tidak dapat dipulihkan
dengan backup tersebut.

Log hasil swap yang tercatat ada di [`screenshots/part2-swap.log`](screenshots/part2-swap.log)
dan screenshot di `screenshots/Screenshot 2026-10-10 043138.png`. Bukti tersebut
menggunakan host port `8081` (bukan `8080`) dan menunjukkan respons berubah dari
versi `1.0.0` menjadi `1.0.1`, sementara container masih menggunakan image
`hello-devops:1.0.0` dengan ukuran 6.86 MB.

## Part III: Jenkins CI/CD

Pipeline didefinisikan di [`Jenkinsfile`](Jenkinsfile) dan deploy script di
[`scripts/deploy.sh`](scripts/deploy.sh). Untuk menghubungkan job ke GitHub,
buat job **Pipeline**, lalu pilih **Pipeline script from SCM** → **Git**; isi
URL repository, branch (misalnya `*/main`), dan Script Path `Jenkinsfile`.
Repository publik tidak memerlukan credential SCM; untuk repository privat,
simpan token GitHub sebagai credential Jenkins.

Urutan stage pipeline:

1. **Checkout**: checkout repository dan ambil short commit hash sebagai tag versi.
2. **Test**: jalankan `go vet ./...` dan `go test -v ./...`. Kegagalan test
	 menghentikan stage berikutnya.
3. **Build Image**: build image `docker.io/<DockerHub-username>/hello-devops:<commit>`.
4. **Push**: login dan push image menggunakan credential Jenkins ber-ID
	 `dockerhub-creds`.
5. **Deploy**: jalankan `scripts/deploy.sh` untuk swap binary pada container target
	 bernama `app` dan health check.

Tambahkan Docker Hub credential melalui **Manage Jenkins → Credentials** dengan
tipe **Username with password**. Isi username Docker Hub, password dengan
Docker Hub access token, dan ID persis `dockerhub-creds`. Jangan simpan token di
Jenkinsfile. Target `app` harus sudah berjalan, dan health endpoint harus dapat
dijangkau dari agent Jenkins di `http://host.docker.internal:8080/` atau melalui
nilai `HEALTH_URL` yang sesuai.

Untuk Jenkins lokal, build dapat dimulai manual melalui **Build Now**. GitHub
webhook tidak dapat mengakses Jenkins di `localhost` tanpa endpoint yang bisa
dijangkau dari internet.

## Deliverables dan bukti

- Source Go, unit test, Dockerfile, Jenkinsfile, dan deploy script berada di root
	repository serta `scripts/`.
- Uraian build, runtime, pendekatan hotfix, ukuran image, alur pipeline, dan
	mekanisme rollback dijelaskan di README ini.
- Bukti Part II tersedia sebagai log dan screenshot di `screenshots/`.
- Tambahkan screenshot atau log build Jenkins dengan seluruh stage sukses setelah
	pipeline terbaru berhasil dijalankan; bukti sukses Jenkins sudah ada di folder
	`screenshots/` saat README ini diperbarui.
- Push repository ke GitHub dan undang `admin@simplejourney.co.id` sebagai reviewer.

