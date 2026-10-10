# DevOps Test - Hello DevOps (Go)

## Versi Go
`go version go1.22.12 linux/amd64` (di dalam container builder `golang:1.22-alpine` / Docker)

## Struktur
- `main.go`, `go.mod`, `Dockerfile`, `.dockerignore` : Part I & II
- `part3-jenkins/` : main.go (handler terpisah), main_test.go, Jenkinsfile, Dockerfile.jenkins
- `scripts/deploy.sh` : swap binary + health check + rollback
- `screenshots/` : bukti

## Part I - Build
Perintah build:
```bash
docker build --build-arg VERSION=1.0.0 -t hello-devops:1.0.0 .
```

Ukuran image: **6.86 MB** (Content size: 2.09 MB)
Output `docker images hello-devops`:
```
REPOSITORY     TAG       IMAGE ID       CREATED         SIZE
hello-devops   1.0.0     8c62f40c9007   5 minutes ago   6.86MB
```

Alasan base image `scratch`: Binary Go dikompilasi secara statis (`CGO_ENABLED=0`) sehingga tidak membutuhkan OS atau shared libraries tambahan dari builder OS. Ukuran image menjadi sangat kecil (hanya seukuran binary Go) dan *attack surface* menjadi sangat minimal karena tidak ada shell atau utility lain. Trade-off: Tanpa shell untuk debugging internal dan tanpa CA certificates default.

## Part II - Deploy
Perintah deploy & swap binary:
```bash
docker run -d --name app -p 8080:8080 --restart unless-stopped hello-devops:1.0.0

# Verifikasi sebelum swap binary:
curl localhost:8080
# Output sebelum: Hello, DevOps! version=1.0.0

# Kompilasi binary baru (v1.0.1) untuk target Linux:
docker run --rm -v "$(pwd):/src" -w /src golang:1.22-alpine go build -trimpath -ldflags="-s -w -X main.version=1.0.1" -o app-new .

# Swap binary & restart container:
docker cp app-new app:/app
docker restart app

# Verifikasi setelah swap binary:
curl localhost:8080
# Output sesudah: Hello, DevOps! version=1.0.1
```

**Penjelasan Pendekatan Hotfix (3-5 kalimat):**
Kami memilih pendekatan menyalin binary baru menggunakan `docker cp` ke dalam container yang sedang berjalan kemudian melakukan `docker restart app`. Metode ini sangat cocok untuk skenario production hotfix darurat karena proses restart container `scratch` hanya membutuhkan *downtime* di bawah 2 detik tanpa perlu melakukan rebuild image Docker dari awal. Selain itu, seluruh atribut container (seperti port mapping, volume, dan restart policy) tetap dipertahankan tanpa perubahan. Trade-off dari pendekatan ini adalah terjadinya *image drift*, di mana binary yang berjalan di dalam container berbeda dengan image dasar yang tersimpan di image registry.

## Part III - Jenkins
Jenkinsfile: `part3-jenkins/Jenkinsfile`. Credential: `dockerhub-creds` (Access Token).
Screenshot run sukses: *(Part III CI/CD Jenkins belum dikonfigurasi)*

Pipeline Jenkins dibuat untuk mengotomatiskan proses build, test, dan deploy aplikasi Go. Proses yang dijalankan dalam pipeline meliputi:
1. Checkout source code dari repositori
2. Test aplikasi dengan `go vet ./...` dan `go test -v ./...`
3. Build Docker image baru dengan tag berdasarkan commit hash Git
4. Push image ke Docker Hub menggunakan Jenkins credentials
5. Deploy binary baru ke container target dengan mekanisme swap binary tanpa rebuild dari Part II

File utama:
- `Jenkinsfile`
- `scripts/deploy.sh`
- `main_test.go`

### Alur pipeline
- Checkout: mengambil source code dari Git
- Test: menjalankan validasi unit test; jika test gagal, pipeline dihentikan dan tidak lanjut ke build/deploy
- Build Image: menjalankan `docker build --build-arg VERSION=${VERSION} -t ${IMAGE} .`
- Push: login ke Docker Hub menggunakan credential Jenkins `dockerhub-creds`
- Deploy: menjalankan `./scripts/deploy.sh ${IMAGE} app`

### Rollback otomatis
Script deploy pada `scripts/deploy.sh` melakukan backup binary lama sebelum mengganti binary baru. Setelah restart, script melakukan health check HTTP. Jika health check gagal, script akan memulihkan binary lama dari backup dan restart container kembali. Dengan mekanisme ini, deploy yang gagal di tengah proses tetap dapat dikembalikan ke versi sebelumnya.

### Catatan penting
- Jenkins credential tidak disimpan secara hardcoded dalam pipeline
- Username Docker Hub dan credential harus disesuaikan dengan akun yang valid sebelum pipeline dijalankan
- Bukti sukses pipeline bisa diambil dari screenshot Jenkins atau log build yang menampilkan semua stage berwarna hijau

### Deliverables
- `Jenkinsfile`
- Screenshot/log pipeline successful run
- Penjelasan rollback otomatis bila deploy gagal

Rollback: `scripts/deploy.sh` melakukan backup binary lama (`docker cp app:/app ./app-backup`), menguji health check HTTP, dan memulihkan binary lama jika health check gagal. Keterbatasan: Rollback gagal jika kesalahan terjadi sebelum backup selesai dilakukan.

