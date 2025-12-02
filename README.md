# Microcoded Lanczos-3 Image Upscaling Engine (µ-LISE)

> Final Project Perancangan Sistem Digital Kelompok 22

> Anggota Kelompok:
> - Reyhan Batara (2406348950)
> - Danish Putra Devananda (2406354202)
> - Mohammad Ariq Haqi (2406431271)
> - Jonathan Christopher (2406349423)

## Project Overview
Microcoded Lanczos-3 Image Upscaling Engine merupakan akselerator *Hardware* yang dirancang untuk meningkatkan resolusi citra digital dengan menggunakan algoritma Lanczos-3 Resampling.

Berbeda dengan implementasi konvensional yang bersifat *Harwired*, sistem ini mengimplementasikan *Microprogramming*. Koefisien filter matematis yang kompleks dapat disimpan sebagai *Micro-instructions* dalam ROM, agar dapat memungkinkan sistem untuk melakukan interpolasi *sub-pixel* dengan presisi tinggi tanpa membebani FPGA *resources* dengan perhitungan trigonometri secara *real-time*.

### *Key Capabilities*
- *High-Quality Upscaling:* Dengan menggunakan *window sampling 6x6 pixels (Lanczos-3)* agar bisa mendapatkan ketajaman yang maksimal.
- *Programmable Filter:* Koefisien filter akan disimpan dalam *Microcoded ROM*, agar memungkinkan adanya penggantian algoritma, misalnya ke Bilinier atau Bicubic, tanpa mengubah *datapath hardware*.
- *Pipeline Processing:* Arsitektur akan dipisah antara *Control Unit* dan *Datapath Unit*-nya.
- *File-Based Simulation:* Dengan menggunakan *Impure Function* untuk membaca atau menulis file citra `.txt` secara otomatis.

---

> Lorem ipsum dolor sit amet. (To Be Continued)