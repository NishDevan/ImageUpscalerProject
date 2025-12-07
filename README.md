# VHDL Lanczos-3 Image Scaler

> Final Project Perancangan Sistem Digital Kelompok 22

> Anggota Kelompok:
> - Reyhan Batara (2406348950)
> - Danish Putra Devananda (2406354202)
> - Mohammad Ariq Haqi (2406431271)
> - Jonathan Christopher (2406349423)

## Project Overview
Proyek ini merupakan suatu implementasi ***High-Quality Image Upscaler*** yang dirancang secara modular menggunakan VHDL. Sistem ini membaca file gambar **BMP (Bitmap)**, melakukan operasi matematika konvolusi 2D dengan menggunakan kernel ***Lanczos-3***, dan menghasilkan file BMP baru dengan resolusi yang telah ditingkatkan.

Inti dari sistem ini adalah ***Lanczos Resample Engine***, yang menghitung interpolasi *pixel* dengan menjaga ketajaman detail (*edge preservation*) yang jauh lebih baik dibandingkan metode standar seperti *Bilinear* atau *Bicubic*.

### *Key Capabilities*
- **True BMP Processing:** *Testbench* mampu membaca dan menulis file `.bmp` 24-bit RGB secara langsung, termasuk menangani *header parsing* dan *byte padding*.
- **Border Replication Strategy:** Menangani masalah tepi gambar (*boundary artifacts*) dengan menduplikasi *pixel* tepi, memastikan kernel *Lanczos* memiliki data valid saat memproses area pinggir.
- **Sub-Pixel Precision:** Menggunakan pemetaan koordinat $(out_x+0.5)/scale - 0.5$ untuk akurasi geometris pusat *pixel*.
- **Separable Convolution:** Melakukan pemfilteran Horizontal dan Vertikal secara berurutan untuk efisiensi komputasi.

---

# System Architecture & Modules
Desain sistem dibagi menjadi 5 file VHDL utama untuk memenuhi prinsip *Structural Programming* dan *Modularity*.

1. `img_types.vhd` (Global Definition)
    - **Fungsi:** Mendefinisikan *custom data type* agar konsisten di seluruh modul.
    - **Isi:** Record `pixel_rgb` (Integer 0 - 255 untuk RGB) dan *array type* 2D `img_buffer`.

2. `border_replicator.vhd` (Pre-Processing)
    - **Fungsi:** Menyiapkan "kanvas" gambar yang lebih besar.
    - **Logika:** Menambahkan *padding* di sekeliling gambar asli. Area kosong akan diisi dengan ***Edge Replication*** (mengulang *pixel* terluar), bukan *zero-padding*, untuk mencegah garis hitam di tepi gambar hasil.

3. `lanczos_resample_engine.vhd` (Inti Dari Segalanya)
    - **Fungsi:** Melakukan komputasi matematika berat (Konvolusi).
    - **Algoritma:**
        - Menghitung koordinat sumber (*float*) dari koordinat target.
        - Menghitung bobot kernel *Lanczos-3* ($sinc(x) \times sinc(x/3)$) untuk *6-tap window*.
        - Melakukan akumulasi nilai *pixel* (Konvolusi) secara horizontal kemudian vertikal.
        - *Saturation/Clamping* hasil ke *range* 0 - 255.

4. `lanczos3_scaler.vhd` (Top Level Controller)
    - **Fungsi:** Pengendali utama (*Wrapper*) yang mengelola *Finite State Machine*.
    - **States:** `IDLE` $\rightarrow$ `BORDER_PREP` $\rightarrow$ `CONVOLVE` $\rightarrow$ `OUTPUT_WAIT` $\rightarrow$ `COMPLETE`.
    - **Output:** Mengirim sinyal `proc_done` dan `status="10"` ke *Testbench* saat gambar selesai diproses.

5. `tb_lanczos3_scaler.vhd` (Testbench & File I/O)
    - **Fungsi:** Jembatan antara simulasi VHDL dan file sistem komputer.
    - **Kapabilitas:**
        - Membaca 54-byte Header BMP.
        - Memodifikasi Header (*Width*, *Height*, *File Size*) untuk *output*.
        - Menangani *Vertical Flip* (BMP disimpan *bottom-to-top*).
        - Menangani ***4-byte Row Padding*** standar format BMP.

---
# Waveform
![Waveform](https://github.com/NishDevan/ImageUpscalerProject/blob/main/Assets/Waveform.jpg)
