# IMAGE UPSCALER

## Penjelasan Program
Sistem ini akan menerima input file citra resolusi rendah dan melakukan upscaling menggunakan algoritma Lanczos-3 untuk menghasilkan output resolusi yang tinggi. Alur data akan diatur oleh FSM yang mengelola Line Buffer untuk memastikan data baris pixel tersedia sebelum diproses. Proses interpolasi akan dikendalikan oleh Microprogramming, di mana instruksi mikro akan memilih bobot dari ROM yang sesuai dengan posisi sub-pixel target. Blok datapath kemudian akan menjalankan operasi konvolusi matriks 6x6 menggunakan Looping dan Fixed-Point Function, lalu akan menyimpan hasil akhirnya ke memori output untuk ditulis kembali ke file eksternal.
