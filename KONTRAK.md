# KONTRAK.md — Project Solaris (Kelompok 1, RSI Kelas A)

Kontrak ini berisi kesepakatan bersama anggota kelompok yaitu nama tabel dan kolom, nilai status, nama role, format response API, kepemilikan file, dan cara mencatat log. Sumber utamanya TSD v1.1 (Bagian 3, 4, 5) dan FSD v2.0 (Bagian 4 dan 6).
---

## 1. Pembagian anggota

| Kode | Bagian | Role yang dilayani |
|---|---|---|
| A | Fondasi dan Admin: repo, skrip inti, kerangka backend, login dan middleware, layout dan menu, komponen UI bersama, log aktivitas, fitur admin, notifikasi | ADMIN, semua role |
| B | Order dan Pengiriman: buyer, order, persetujuan kontrak, pembatalan, riwayat harga, dashboard, rekap, pengiriman dan surat jalan | MARKETING, PIMPINAN |
| C | Produksi: supplier, bahan baku, SPK dan persetujuannya, progres harian, hasil QC, salinan bertanda tangan | PPIC, SPV, QC |

Nama anggota:

- A = Tanerski Gabriela Gienaldi
- B = Nabila Azahra Putri
- C = Sausan Nisa Zhaafirah 

---

## 2. File skrip database dan pemiliknya

Semua skrip SQL ada di folder `db/` dan dijalankan **berurutan dari nomor terkecil**. Setiap objek (tabel, function, procedure, view, trigger) dipisah dengan baris `GO`, supaya skripnya bisa dijalankan di SSMS maupun DBeaver.

| Urutan | File | Pemilik | Isi |
|---|---|---|---|
| 0 | `00-reset.sql` | A | `DROP DATABASE` bila ada, lalu `CREATE DATABASE solaris_db` |
| 1 | `01-core.sql` | A | roles, users, sessions, activity_logs, password_reset_requests, notifications |
| 2 | `02-order.sql` | B | buyers, product_types, items, orders, order_status_history, order_styles, order_style_sizes, shipments, shipment_items |
| 3 | `03-produksi.sql` | C | suppliers, materials, spk, spk_sizes, production_progress, qc_results, signed_documents |
| 4 | `04-objects-core.sql` | A | function, procedure, view, dan trigger milik A (Bagian 3) |
| 5 | `05-objects-produksi.sql` | C | function, procedure, view, dan trigger milik C (Bagian 3) |
| 6 | `06-objects-order.sql` | B | function, procedure, view, dan trigger milik B (Bagian 3) |
| 7 | `90-seed-core.sql` | A | 6 role dan 6 akun demo (Bagian 12) |
| 8 | `91-seed-order.sql` | B | jenis produk, buyer, barang, dan minimal 1 order berstatus DISETUJUI lengkap dengan style dan ukurannya |
| 9 | `92-seed-produksi.sql` | C | 2 supplier dan bahan untuk order seed milik B |

Catatan:

- File 05 (C) dijalankan **sebelum** file 06 (B), karena `v_dashboard_orders` dan `sp_record_shipment` milik B memakai function milik C.
- Data seed dipisah ke file 90–92, supaya file tabel bisa diubah tanpa ikut mengubah data.
- Setiap perubahan tabel **wajib** lewat skrip di repo. Jangan mengubah tabel langsung di SSMS atau DBeaver tanpa menuliskannya ke skrip (R-03).
- Menjalankan ulang dari nol: jalankan semua file mulai dari `00-reset.sql`.

---

## 3. Objek database (TSD Bagian 5) dan pemiliknya

| Pemilik | Stored procedure | Function | View | Trigger |
|---|---|---|---|---|
| A | sp_record_login, sp_reset_password, sp_create_notification | fn_next_doc_no (dipakai B dan C) | v_active_sessions, v_login_history | trg_activity_logs_append_only |
| B | sp_create_order, sp_change_order_status, sp_record_shipment | fn_next_order_code, fn_next_item_code | v_order_summary, v_price_history, v_dashboard_orders, v_shipment_history | trg_orders_immutable, trg_no_delete_transactions (untuk tabel B) |
| C | sp_submit_spk, sp_decide_spk, sp_evaluate_flags | fn_material_readiness, fn_material_locked, fn_stage_max_allowed, fn_style_completion_pct, fn_time_elapsed_pct, fn_reject_pct, fn_ready_to_ship, fn_next_doc_version | v_style_progress, v_supplier_materials, v_spk_list, v_latest_signed_documents | trg_materials_lock, trg_signed_documents_append_only, trg_no_delete_transactions (untuk tabel C) |

**Titik sambung antarmodul.** Function milik satu anggota yang dipakai anggota lain:

| Function | Dibuat oleh | Dipakai oleh | Untuk |
|---|---|---|---|
| fn_ready_to_ship(@style_id) | C | B | Batas jumlah kiriman (Packing selesai dikurangi yang sudah dikirim) |
| fn_style_completion_pct(@style_id) | C | B | Persen selesai di dashboard |
| fn_time_elapsed_pct(@style_id) | C | B | Persen waktu terpakai di dashboard |
| fn_reject_pct(@style_id) | C | B | Persen tidak lolos di dashboard |
| fn_next_doc_no(@prefix, @at) | A | B (SJ), C (SPK) | Nomor surat jalan dan nomor SPK |
| sp_create_notification | A | B, C | Membuat notifikasi (Bagian 11) |

Nama dan parameter function di tabel ini tidak boleh diubah tanpa persetujuan anggota yang memakainya.

---

## 4. Tabel dan kolom (TSD Bagian 4.3)

Konvensi:

- Nama tabel dan kolom memakai `snake_case` berbahasa Inggris. Nama tabel berbentuk jamak, kecuali `spk`.
- ID memakai `UNIQUEIDENTIFIER DEFAULT NEWSEQUENTIALID()`. Pengecualian: `activity_logs` dan `order_status_history` memakai `BIGINT IDENTITY`. `roles` dan `product_types` memakai kode sebagai primary key.
- Teks memakai `NVARCHAR`. Kode tetap memakai `VARCHAR`/`CHAR`.
- Nilai status disimpan sebagai `VARCHAR` dengan `CHECK` constraint (lihat Bagian 5).
- Waktu memakai `DATETIME2(0)` dengan default `SYSDATETIME()`. Tanggal saja memakai `DATE`.

Singkatan di kolom Keterangan: PK = primary key, FK = foreign key, UQ = unique, CK = check, DF = default.

### 4.1 Milik A (`01-core.sql`)

**roles**

| Kolom | Tipe | Keterangan |
|---|---|---|
| role_code | VARCHAR(10) | PK; nilai di Bagian 6 |
| role_name | NVARCHAR(50) | Nama tampilan, mis. "Administrator Sistem" |
| access_tier | VARCHAR(10) | CK IN (SUPERADMIN, ADMIN, USER) |

**users**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| full_name | NVARCHAR(100) | |
| username | VARCHAR(50) | UQ; CK panjang 4–50 |
| password_hash | VARCHAR(100) | Hash bcrypt, tidak pernah teks biasa |
| role_code | VARCHAR(10) | FK → roles |
| is_active | BIT | DF 1 |
| is_locked | BIT | DF 0; jadi 1 setelah 5 kali gagal login |
| failed_login_count | TINYINT | DF 0 |
| must_change_password | BIT | DF 0; jadi 1 setelah reset password |
| last_login_at | DATETIME2(0) | NULL |
| created_at, updated_at | DATETIME2(0) | DF SYSDATETIME() |

**sessions**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK; disimpan di JWT sebagai klaim `sid` |
| user_id | UNIQUEIDENTIFIER | FK → users |
| device | NVARCHAR(150) | Ringkasan User-Agent, mis. "Android · Chrome" |
| ip_address | VARCHAR(45) | |
| login_at | DATETIME2(0) | DF SYSDATETIME() |
| last_activity_at | DATETIME2(0) | Diperbarui setiap request; dasar timeout 30 menit |
| status | VARCHAR(10) | DF 'AKTIF'; nilai di Bagian 5 |
| end_reason | VARCHAR(20) | NULL; nilai di Bagian 5 |
| ended_at | DATETIME2(0) | NULL |

**activity_logs** (hanya ditambah, tidak pernah diubah atau dihapus)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | BIGINT IDENTITY(1,1) | PK |
| user_id | UNIQUEIDENTIFIER | NULL; FK → users (NULL bila username tidak dikenal) |
| username | VARCHAR(50) | Username saat kejadian |
| action_type | VARCHAR(20) | Nilai di Bagian 10 |
| resource_type | VARCHAR(30) | NULL; nama tabel yang terpengaruh |
| resource_id | VARCHAR(36) | NULL; id baris yang terpengaruh |
| old_values, new_values | NVARCHAR(MAX) | NULL; JSON, CK ISJSON = 1 |
| device | NVARCHAR(150) | NULL |
| ip_address | VARCHAR(45) | |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**password_reset_requests**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| user_id | UNIQUEIDENTIFIER | FK → users |
| note | NVARCHAR(200) | NULL |
| status | VARCHAR(10) | DF 'MENUNGGU'; nilai di Bagian 5 |
| handled_by | UNIQUEIDENTIFIER | NULL; FK → users |
| requested_at | DATETIME2(0) | DF SYSDATETIME() |
| handled_at | DATETIME2(0) | NULL |

**notifications**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| recipient_id | UNIQUEIDENTIFIER | FK → users |
| event_code | CHAR(4) | 'N-01' sampai 'N-13' (Bagian 11) |
| message | NVARCHAR(300) | |
| link | VARCHAR(200) | NULL; route frontend |
| dedup_key | VARCHAR(80) | NULL; mencegah notifikasi ganda |
| is_read | BIT | DF 0 |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

### 4.2 Milik B (`02-order.sql`)

**buyers**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| buyer_name | NVARCHAR(100) | |
| buyer_code | CHAR(3) | UQ; CK 3 huruf kapital, mis. BRT |
| contact | NVARCHAR(100) | |
| created_at, updated_at | DATETIME2(0) | DF SYSDATETIME() |

**product_types**

| Kolom | Tipe | Keterangan |
|---|---|---|
| type_code | CHAR(2) | PK: CL, KM, KS, PL, DR, JK, SR |
| type_name | NVARCHAR(30) | |

**items**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| item_code | VARCHAR(12) | UQ; format BBB-JJ-NNNN |
| buyer_id | UNIQUEIDENTIFIER | FK → buyers |
| type_code | CHAR(2) | FK → product_types |
| buyer_style_name | NVARCHAR(100) | |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**orders**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| order_code | CHAR(12) | UQ; format ORD-TTBB-NNN |
| buyer_id | UNIQUEIDENTIFIER | FK → buyers |
| order_date | DATE | DF hari ini |
| deadline | DATE | CK deadline >= order_date |
| scheme | VARCHAR(3) | CK IN (CMT, FOB) |
| reject_limit_pct | DECIMAL(5,2) | CK 0–100 |
| late_penalty | NVARCHAR(500) | |
| status | VARCHAR(20) | DF 'MENUNGGU_PERSETUJUAN'; nilai di Bagian 5 |
| is_at_risk | BIT | DF 0 |
| is_over_reject | BIT | DF 0 |
| created_by | UNIQUEIDENTIFIER | FK → users |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**order_status_history**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | BIGINT IDENTITY(1,1) | PK |
| order_id | UNIQUEIDENTIFIER | FK → orders |
| status | VARCHAR(20) | Status baru |
| changed_by | UNIQUEIDENTIFIER | FK → users |
| reason | NVARCHAR(500) | NULL; wajib bila status DITOLAK, DITARIK, atau DIBATALKAN |
| changed_at | DATETIME2(0) | DF SYSDATETIME() |

**order_styles**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| order_id | UNIQUEIDENTIFIER | FK → orders |
| item_id | UNIQUEIDENTIFIER | FK → items |
| color | NVARCHAR(50) | |
| price_per_pcs | DECIMAL(14,2) | CK > 0 |
| is_at_risk | BIT | DF 0 |
| is_over_reject | BIT | DF 0 |

**order_style_sizes**

| Kolom | Tipe | Keterangan |
|---|---|---|
| style_id | UNIQUEIDENTIFIER | PK bagian 1; FK → order_styles |
| size | VARCHAR(10) | PK bagian 2; mis. S, M, L, XL, 28 |
| qty | INT | CK > 0 |

**shipments**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| delivery_note_no | CHAR(11) | UQ; format SJ-TTBB-NNN |
| order_id | UNIQUEIDENTIFIER | FK → orders |
| ship_date | DATE | |
| expedition | NVARCHAR(100) | |
| recorded_by | UNIQUEIDENTIFIER | FK → users |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**shipment_items**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| shipment_id | UNIQUEIDENTIFIER | FK → shipments |
| style_id | UNIQUEIDENTIFIER | FK → order_styles |
| size | VARCHAR(10) | UQ (shipment_id, style_id, size) |
| qty | INT | CK > 0 |

### 4.3 Milik C (`03-produksi.sql`)

**suppliers**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| supplier_name | NVARCHAR(100) | |
| contact | NVARCHAR(100) | |
| payment_term | VARCHAR(10) | Nilai di Bagian 5 |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**materials**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| style_id | UNIQUEIDENTIFIER | FK → order_styles |
| material_name | NVARCHAR(100) | |
| qty | DECIMAL(12,2) | CK > 0 |
| unit | NVARCHAR(20) | |
| source | VARCHAR(8) | CK IN (BUYER, SUPPLIER) |
| supplier_id | UNIQUEIDENTIFIER | NULL; FK → suppliers; wajib bila source = SUPPLIER |
| material_price | DECIMAL(14,2) | NULL; CK > 0; wajib bila source = SUPPLIER |
| received_date | DATE | |
| checked_by | UNIQUEIDENTIFIER | FK → users (PPIC yang mencentang pernyataan kelayakan) |
| checked_at | DATETIME2(0) | DF SYSDATETIME() |
| updated_at | DATETIME2(0) | DF SYSDATETIME() |

**spk**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| spk_no | CHAR(12) | UQ; format SPK-TTBB-NNN |
| style_id | UNIQUEIDENTIFIER | FK → order_styles; satu SPK berlaku per style |
| target_date | DATE | |
| status | VARCHAR(20) | DF 'MENUNGGU_PERSETUJUAN'; nilai di Bagian 5 |
| materials_complete_by | UNIQUEIDENTIFIER | FK → users (PPIC yang mencentang pernyataan bahan lengkap) |
| decided_by | UNIQUEIDENTIFIER | NULL; FK → users (Pimpinan) |
| approved_at | DATETIME2(0) | NULL |
| reject_reason | NVARCHAR(500) | NULL; wajib bila status DITOLAK |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**spk_sizes**

| Kolom | Tipe | Keterangan |
|---|---|---|
| spk_id | UNIQUEIDENTIFIER | PK bagian 1; FK → spk |
| size | VARCHAR(10) | PK bagian 2 |
| qty | INT | CK > 0 |

**production_progress**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| spk_id | UNIQUEIDENTIFIER | FK → spk |
| stage | VARCHAR(10) | Nilai di Bagian 5 |
| work_date | DATE | UQ (spk_id, stage, work_date) |
| qty_done | INT | CK >= 0 |
| variance_note | NVARCHAR(300) | NULL; wajib bila jumlah Cutting ≠ jumlah SPK |
| recorded_by | UNIQUEIDENTIFIER | FK → users (Supervisor) |
| created_at, updated_at | DATETIME2(0) | DF SYSDATETIME() |

**qc_results**

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| spk_id | UNIQUEIDENTIFIER | FK → spk |
| stage | VARCHAR(10) | Semua tahap kecuali PACKING |
| check_date | DATE | |
| qty_passed | INT | CK >= 0 |
| recorded_by | UNIQUEIDENTIFIER | FK → users (QC) |
| created_at | DATETIME2(0) | DF SYSDATETIME() |

**signed_documents** (prioritas Terakhir; hanya ditambah)

| Kolom | Tipe | Keterangan |
|---|---|---|
| id | UNIQUEIDENTIFIER | PK |
| doc_type | VARCHAR(12) | CK IN (SPK, SURAT_JALAN) |
| spk_id | UNIQUEIDENTIFIER | NULL; FK → spk; wajib bila doc_type = SPK |
| shipment_id | UNIQUEIDENTIFIER | NULL; FK → shipments; wajib bila doc_type = SURAT_JALAN |
| version | INT | CK >= 1; nomor urut per dokumen |
| original_name | NVARCHAR(200) | Nama berkas asli |
| stored_name | VARCHAR(45) | UQ; `{uuid}.{jpg|png|pdf}` |
| mime_type | VARCHAR(30) | CK IN (image/jpeg, image/png, application/pdf) |
| size_bytes | INT | CK 1–5242880 (5 MB) |
| sha256 | CHAR(64) | |
| uploaded_by | UNIQUEIDENTIFIER | FK → users |
| uploaded_at | DATETIME2(0) | DF SYSDATETIME() |

Ditambah CHECK: tepat satu dari `spk_id` dan `shipment_id` terisi.

Index mengikuti TSD 4.4 dan ditulis oleh pemilik tabelnya, di file tabel masing-masing.

---

## 5. Nilai status dan pilihan tetap

Teks status ditulis **HURUF KAPITAL dengan garis bawah**, persis seperti di bawah ini. Di kode backend, nilai ini diambil dari `constants.ts` (Bagian 7). Jangan mengetik ulang teksnya.

| Tabel.kolom | Nilai yang boleh |
|---|---|
| orders.status | MENUNGGU_PERSETUJUAN, DISETUJUI, DITOLAK, DITARIK, DALAM_PRODUKSI, SELESAI, DIBATALKAN |
| spk.status | MENUNGGU_PERSETUJUAN, DISETUJUI, DITOLAK |
| sessions.status | AKTIF, BERAKHIR |
| sessions.end_reason | LOGOUT, TIDAK_AKTIF, DIAKHIRI_ADMIN, RESET_PASSWORD, AKUN_NONAKTIF |
| password_reset_requests.status | MENUNGGU, SELESAI |
| orders.scheme | CMT, FOB |
| suppliers.payment_term | LUNAS_AWAL, DP, KREDIT |
| materials.source | BUYER, SUPPLIER |
| production_progress.stage | CUTTING, SEWING, TRIMMING, FINISHING, IRONING, PACKING (urutan tetap) |
| qc_results.stage | CUTTING, SEWING, TRIMMING, FINISHING, IRONING |
| signed_documents.doc_type | SPK, SURAT_JALAN |
| roles.access_tier | SUPERADMIN, ADMIN, USER |
| product_types.type_code | CL, KM, KS, PL, DR, JK, SR |
| Status kesiapan bahan (hasil fn_material_readiness) | SIAP, BELUM_SIAP |

**Perpindahan status order:**

| Dari | Ke | Oleh | Endpoint |
|---|---|---|---|
| (baru) | MENUNGGU_PERSETUJUAN | MARKETING | POST /orders |
| MENUNGGU_PERSETUJUAN | DISETUJUI | PIMPINAN | POST /orders/{id}/approve |
| MENUNGGU_PERSETUJUAN | DITOLAK (final) | PIMPINAN | POST /orders/{id}/reject (alasan wajib) |
| MENUNGGU_PERSETUJUAN | DITARIK (final) | MARKETING | POST /orders/{id}/withdraw (alasan wajib) |
| DISETUJUI | DALAM_PRODUKSI | otomatis | saat SPK pertama order itu disetujui |
| DISETUJUI atau DALAM_PRODUKSI | DIBATALKAN | PIMPINAN | POST /orders/{id}/cancel (alasan wajib) |
| DALAM_PRODUKSI | SELESAI | otomatis | saat pengiriman dicatat |

**Perpindahan status SPK:** SPK dibuat dengan status MENUNGGU_PERSETUJUAN, lalu menjadi DISETUJUI atau DITOLAK oleh PIMPINAN. Alasan wajib diisi bila ditolak. Setelah SPK ditolak, PPIC boleh mengajukan SPK baru untuk style yang sama.

---

## 6. Role

| role_code | Nama tampilan | access_tier |
|---|---|---|
| ADMIN | Administrator Sistem | SUPERADMIN |
| PIMPINAN | Pimpinan | ADMIN |
| MARKETING | Marketing | USER |
| PPIC | PPIC | USER |
| SPV | Supervisor | USER |
| QC | Quality Control | USER |

`role_code` ditulis persis seperti di atas, baik di database, di JWT, di `authorize(...)`, maupun di frontend. Contohnya `SPV`, bukan `SUPERVISOR`.

---

## 7. Konvensi kode

### 7.1 Struktur folder backend

```
backend/src/
  db/
    index.ts          (koneksi, dibuat A)
    schema/
      index.ts        (hanya export dari 3 file di bawah, dibuat A)
      core.ts         (A)
      order.ts        (B)
      produksi.ts     (C)
  routes/index.ts     (memasang semua router, dibuat A pada Hari 2)
  routes/<modul>.routes.ts
  controllers/<modul>.controller.ts
  services/<modul>.service.ts
  repositories/<modul>.repository.ts
  schemas/<modul>.schema.ts      (Zod)
  middlewares/                   (authenticate, authorize, validate, error handler; dibuat A)
  constants.ts                   (dibuat A)
  db/pool.ts                     (getPool() untuk mssql, dibuat A)
  utils/response.ts, utils/errors.ts, utils/activity-log.ts, utils/transaction.ts   (dibuat A)
```

Nama `<modul>` dan pemiliknya:

| Pemilik | Modul |
|---|---|
| A | auth, users, sessions, password-reset-requests, activity-logs, notifications |
| B | buyers, orders, price-history, dashboard, reports, shipments |
| C | suppliers, materials, spk, progress, qc-results, signed-documents |

Urutan middleware di setiap route: `authenticate` → `authorize(...)` → `validate(schema)` → controller.

Lapisan: router → controller → service → repository. Controller hanya membaca request dan mengirim response. Aturan bisnis ada di service. Query database hanya ada di repository.

### 7.2 Penamaan

| Hal | Aturan | Contoh |
|---|---|---|
| Tabel dan kolom | snake_case | `order_styles.price_per_pcs` |
| Properti Drizzle | Sama persis dengan nama kolom | `price_per_pcs: decimal('price_per_pcs', ...)` |
| Field JSON request/response | snake_case | `{ "buyer_id": "...", "reject_limit_pct": 3 }` |
| URL | Jamak, kebab-case, aksi sebagai sub-resource | `/api/v1/order-styles/{styleId}/materials`, `/orders/{id}/approve` |
| File | kebab-case dengan akhiran lapisan | `price-history.service.ts` |
| Variabel dan fungsi TS | camelCase | `getOrderById` |
| Komponen React | PascalCase | `OrderForm.tsx` |
| Konstanta | UPPER_SNAKE_CASE | `ORDER_STATUS.DISETUJUI` |

### 7.3 Isi `constants.ts`

```ts
export const ROLE = {
  ADMIN: 'ADMIN', PIMPINAN: 'PIMPINAN', MARKETING: 'MARKETING',
  PPIC: 'PPIC', SPV: 'SPV', QC: 'QC',
} as const;

export const ORDER_STATUS = {
  MENUNGGU_PERSETUJUAN: 'MENUNGGU_PERSETUJUAN', DISETUJUI: 'DISETUJUI',
  DITOLAK: 'DITOLAK', DITARIK: 'DITARIK', DALAM_PRODUKSI: 'DALAM_PRODUKSI',
  SELESAI: 'SELESAI', DIBATALKAN: 'DIBATALKAN',
} as const;

export const SPK_STATUS = {
  MENUNGGU_PERSETUJUAN: 'MENUNGGU_PERSETUJUAN', DISETUJUI: 'DISETUJUI', DITOLAK: 'DITOLAK',
} as const;

export const STAGES = ['CUTTING', 'SEWING', 'TRIMMING', 'FINISHING', 'IRONING', 'PACKING'] as const;
export const QC_STAGES = ['CUTTING', 'SEWING', 'TRIMMING', 'FINISHING', 'IRONING'] as const;

export const SESSION_STATUS = { AKTIF: 'AKTIF', BERAKHIR: 'BERAKHIR' } as const;
export const SESSION_END_REASON = {
  LOGOUT: 'LOGOUT', TIDAK_AKTIF: 'TIDAK_AKTIF', DIAKHIRI_ADMIN: 'DIAKHIRI_ADMIN',
  RESET_PASSWORD: 'RESET_PASSWORD', AKUN_NONAKTIF: 'AKUN_NONAKTIF',
} as const;

export const SCHEME = ['CMT', 'FOB'] as const;
export const PAYMENT_TERM = ['LUNAS_AWAL', 'DP', 'KREDIT'] as const;
export const MATERIAL_SOURCE = ['BUYER', 'SUPPLIER'] as const;
export const DOC_TYPE = { SPK: 'SPK', SURAT_JALAN: 'SURAT_JALAN' } as const;

// Peran yang boleh melihat harga (TSD AC-08)
export const PRICE_VISIBLE_ROLES = [ROLE.MARKETING, ROLE.PIMPINAN];
```

Nilai `ACTION_TYPE` (Bagian 10) dan `NOTIF` (Bagian 11) juga ditaruh di file ini.

---

## 8. Format API

### 8.1 Dasar

- Base URL backend: `http://localhost:3000/api/v1`. Swagger ada di `http://localhost:3000/docs`.
- Method yang dipakai: GET (baca), POST (buat data atau aksi status), PATCH (ubah sebagian). **DELETE tidak dipakai**, karena data transaksi tidak boleh dihapus.
- Format data:
  - Tanggal: `YYYY-MM-DD`
  - Waktu: ISO 8601 dengan zona `+07:00`
  - Uang: angka dalam Rupiah dengan 2 desimal
  - ID: UUID dalam bentuk string
- Halaman daftar memakai query `?page=1&per_page=20`. Hasilnya dilengkapi `meta`.
- Kolom harga (`price_per_pcs`, `material_price`, `total_value`) **dihapus dari response** untuk role selain MARKETING dan PIMPINAN. Ini dikerjakan di service, sebelum response dikirim.

### 8.2 Bentuk response

Sukses:

```json
{ "status": "success", "data": { }, "message": "Order berhasil disimpan." }
```

Sukses untuk daftar:

```json
{ "status": "success", "data": [ ], "meta": { "current_page": 1, "per_page": 20, "total": 57, "last_page": 3 } }
```

Error:

```json
{
  "status": "error",
  "error_code": "ERR-VAL-01",
  "message": "Kolom ini wajib diisi.",
  "errors": [ { "field": "deadline", "message": "Kolom ini wajib diisi." } ]
}
```

- `error_code` dan `message` diambil dari tabel kode error FSD Bagian 6. Teksnya disalin persis.
- `errors` hanya diisi untuk kesalahan per kolom (validasi Zod).
- Detail teknis seperti stack trace atau pesan SQL **tidak** dikirim ke frontend. Detail itu cukup ditulis ke `console.error` di server.
- Helper yang dipakai semua anggota (dibuat A): `sendSuccess(res, data, message?, meta?, statusCode?)` dan `throw new AppError(httpStatus, 'ERR-XXX-NN', message?)`.

### 8.3 Kode HTTP

| Kode | Dipakai untuk |
|---|---|
| 200 | Berhasil membaca atau mengubah |
| 201 | Berhasil membuat data baru |
| 202 | Permintaan diterima (ajukan reset password) |
| 401 | Belum login atau sesi berakhir (ERR-AUTH-01/04/05, ERR-AUTH-02 saat login) |
| 403 | Role tidak berhak (ERR-AUTH-03), atau wajib ganti password dulu (ERR-AUTH-07) |
| 404 | Data tidak ditemukan |
| 409 | Melanggar aturan bisnis, mis. order sudah diputuskan (ERR-ORD-02) |
| 422 | Isian tidak valid (ERR-VAL-xx) |
| 423 | Akun terkunci (ERR-AUTH-06) |
| 500 / 503 | Kesalahan server (ERR-SYS-02) / database tidak bisa diakses (ERR-SYS-01) |

### 8.4 Kelompok kode error (FSD Bagian 6) dan pemiliknya

| Awalan | Isi | Pemilik |
|---|---|---|
| ERR-AUTH-01 sampai 07 | Login, sesi, hak akses | A |
| ERR-USR-01, ERR-SES-01 | Akun dan sesi | A |
| ERR-VAL-01 sampai 14 | Validasi isian (dipakai semua) | Semua |
| ERR-ORD-01 sampai 05 | Order | B |
| ERR-KRM-01, 02 | Pengiriman | B |
| ERR-BHN-01 | Bahan baku | C |
| ERR-SPK-01 sampai 04 | SPK | C |
| ERR-PRG-01 sampai 04 | Progres | C |
| ERR-QC-01, 02 | Hasil QC | C |
| ERR-DOK-01, 02 | Salinan bertanda tangan | C (dipakai juga oleh B) |
| ERR-SYS-01, 02 | Kesalahan sistem | A (error handler) |

---

## 9. Login dan sesi

- Login: `POST /api/v1/auth/login` dengan body `{ "username": "...", "password": "..." }`.
- Token JWT berlaku 8 jam dan disimpan di **cookie HttpOnly bernama `token`**, sama seperti praktikum. Frontend memakai axios dengan `withCredentials: true` dan tidak pernah membaca token itu sendiri.
- Isi JWT: `{ sub: user_id, role: role_code, sid: session_id }`.
- Di setiap request, `authenticate` memeriksa tiga hal. Pertama, tokennya valid. Kedua, sesi `sid` di tabel `sessions` masih AKTIF. Ketiga, `last_activity_at` belum lewat 30 menit. Bila lolos, `last_activity_at` diperbarui. Bila tidak lolos, server mengirim 401 dengan kode ERR-AUTH-04 atau ERR-AUTH-05.
- `authorize(ROLE.PIMPINAN, ...)` menolak role lain dengan 403 ERR-AUTH-03 dan mencatat log AKSES_DITOLAK.
- Akun terkunci setelah 5 kali gagal login berturut-turut. Password minimal 8 karakter dan di-hash dengan bcrypt.
- `GET /api/v1/auth/me` mengembalikan `{ id, full_name, username, role_code, menus, unread_notifications }`. Frontend memakai `menus` untuk membentuk sidebar.

---

## 10. Log aktivitas

Log dicatat oleh **service**, di dalam transaksi yang sama dengan perubahan datanya, memakai helper buatan A di `utils/activity-log.ts`:

```ts
await logActivity(tx, {
  user_id: req.user.id,          // null bila username tidak dikenal
  username: req.user.username,
  action_type: ACTION_TYPE.SETUJU,
  resource_type: 'orders',       // nama tabel
  resource_id: order.id,
  old_values: { status: 'MENUNGGU_PERSETUJUAN' },   // opsional
  new_values: { status: 'DISETUJUI' },              // opsional
  device, ip_address,
});
```

Kalau transaksi gagal, log ikut dibatalkan, jadi tidak ada log untuk aksi yang tidak terjadi.

### 10.1 Pola transaksi (disepakati 16/11/2026)

Pola ini mengikuti contoh audit log praktikum pertemuan 9.

| Jenis query | Dipakai | Keterangan |
|---|---|---|
| **Tulis** (simpan, ubah, setujui, tolak, batal, unggah) | `withTransaction()` + `sql.Transaction` dari `mssql` | Semua query di dalamnya memakai `new sql.Request(transaction)`, termasuk pemanggilan SP dan `logActivity` |
| **Baca** (daftar, detail, dashboard) | Drizzle (`getDb()`) atau view | Tidak perlu transaksi |

- `tx` di `logActivity(tx, ...)` bertipe `sql.Transaction`.
- Jangan memakai `db.transaction()` milik Drizzle, karena tidak bisa digabung dengan `sql.Transaction`.
- Parameter selalu lewat `.input('nama', sql.Tipe, nilai)`. Jangan menyambung teks ke dalam query.

Helper buatan A di `utils/transaction.ts`:

```ts
export async function withTransaction<T>(
  work: (transaction: sql.Transaction) => Promise<T>,
): Promise<T> {
  const transaction = new sql.Transaction(await getPool());
  await transaction.begin();
  try {
    const result = await work(transaction);
    await transaction.commit();
    return result;
  } catch (error) {
    try { await transaction.rollback(); } catch { /* sudah di-rollback SQL Server */ }
    throw error;
  }
}
```

Contoh di service (C, setujui SPK):

```ts
return withTransaction(async (tx) => {
  const spk = await this.spkRepository.decide(tx, { spk_id, decision: 'DISETUJUI', decided_by: user.id });
  await logActivity(tx, {
    user_id: user.id, username: user.username,
    action_type: ACTION_TYPE.SETUJU, resource_type: 'spk', resource_id: spk_id,
    old_values: { status: SPK_STATUS.MENUNGGU_PERSETUJUAN },
    new_values: { status: SPK_STATUS.DISETUJUI },
    device, ip_address,
  });
  return spk;
});

// di repository
async decide(tx: sql.Transaction, p: DecideSpkInput) {
  const result = await new sql.Request(tx)
    .input('spk_id', sql.UniqueIdentifier, p.spk_id)
    .input('decision', sql.VarChar(20), p.decision)
    .input('decided_by', sql.UniqueIdentifier, p.decided_by)
    .execute('sp_decide_spk');
  return result.recordset[0];
}
```

Nilai `action_type` (17 nilai, FSD Entitas 2):

| Nilai | Dicatat saat | Dicatat oleh |
|---|---|---|
| LOGIN_BERHASIL, LOGIN_GAGAL, LOGOUT | Login berhasil, gagal, dan keluar | A |
| SESI_BERAKHIR, SESI_DIAKHIRI | Sesi habis karena tidak aktif, atau diakhiri Administrator | A |
| AKUN_TERKUNCI, BUKA_KUNCI | Akun terkunci setelah 5 kali gagal, dan dibuka Administrator | A |
| RESET_PASSWORD, GANTI_PASSWORD | Reset oleh Administrator, dan ganti password sementara | A |
| AKSES_DITOLAK | Role membuka fungsi yang bukan haknya (di `authorize`) | A |
| TAMBAH, UBAH | Menyimpan atau mengubah data apa pun (buyer, order, supplier, bahan, SPK, progres, QC, pengiriman, akun) | Pemilik modul |
| SETUJU, TOLAK | Persetujuan atau penolakan order dan SPK | B (order), C (SPK) |
| TARIK, BATAL | Tarik pengajuan order, dan batalkan order | B |
| UNGGAH_DOKUMEN | Unggah salinan bertanda tangan | C, B |

Syarat RPS: login, logout, dan akses ditolak harus tercatat. Ini dicek di Hari 11.

---

## 11. Notifikasi

Notifikasi dibuat lewat `sp_create_notification` (milik A), dari dalam SP atau service pemilik kejadian. Isi `message` mengikuti contoh di SRS Tabel 3.2a.

| Kode | Kejadian | Penerima | Dibuat oleh |
|---|---|---|---|
| N-01 | Order baru disimpan | PIMPINAN | B |
| N-02 | SPK diajukan | PIMPINAN | C |
| N-03 | Order disetujui atau ditolak | MARKETING, PPIC | B |
| N-04 | Pengajuan order ditarik | PIMPINAN | B |
| N-05 | SPK disetujui atau ditolak | PPIC; SPV hanya bila disetujui | C |
| N-06 | Order dibatalkan | MARKETING, PPIC, SPV, QC | B |
| N-07 | Style atau order pertama kali berisiko terlambat | PIMPINAN, PPIC | C (sp_evaluate_flags) |
| N-08 | Persen tidak lolos pertama kali melebihi batas reject | PIMPINAN, PPIC | C (sp_evaluate_flags) |
| N-09 | Pengiriman dicatat, order selesai | PIMPINAN, MARKETING | B |
| N-10 | Ada permintaan reset password | ADMIN | A |
| N-11 | Akun terkunci | ADMIN | A |
| N-12 | Salinan SPK bertanda tangan diunggah | PPIC, SPV | C |
| N-13 | Salinan surat jalan bertanda tangan diunggah | PIMPINAN, MARKETING | B |

Frontend memanggil `GET /api/v1/notifications` setiap 30 detik (dibuat A).

---

## 12. Format nomor dan akun demo

**Format nomor** (dibuat oleh function, bukan diketik pengguna):

| Nomor | Format | Contoh | Function |
|---|---|---|---|
| Kode order | ORD-TTBB-NNN | ORD-2611-003 | fn_next_order_code |
| Kode barang | BBB-JJ-NNNN | BRT-KS-0005 | fn_next_item_code |
| Nomor SPK | SPK-TTBB-NNN | SPK-2611-004 | fn_next_doc_no('SPK', ...) |
| Nomor surat jalan | SJ-TTBB-NNN | SJ-2611-012 | fn_next_doc_no('SJ', ...) |

Keterangan: TT = 2 digit tahun, BB = bulan, NNN/NNNN = nomor urut, BBB = kode buyer, JJ = kode jenis produk.

**Akun demo** (di `90-seed-core.sql`):

| username | role_code | Password |
|---|---|---|
| admin.solaris | ADMIN | `Solaris#2026` |
| pimpinan | PIMPINAN | `Solaris#2026` |
| marketing | MARKETING | `Solaris#2026` |
| ppic | PPIC | `Solaris#2026` |
| supervisor | SPV | `Solaris#2026` |
| qc.solaris | QC | `Solaris#2026` |

Semua akun memakai password yang sama, supaya mudah dipakai saat uji coba. A membuat hash bcrypt-nya sekali, lalu menempelkannya ke file seed:

```
node -e "console.log(require('bcryptjs').hashSync('Solaris#2026', 12))"
```

Username minimal 4 karakter (CHECK di tabel users). Karena itu akun QC memakai `qc.solaris`, bukan `qc`.

---

## 13. Endpoint dan pemiliknya (TSD 3.2)

Semua URL diawali `/api/v1`. Tanda "Prioritas" mengikuti tabel prioritas di Rencana Kerja: W = Wajib, S = Kalau sempat, T = Terakhir.

**A: Fondasi dan Admin**

| Method | URL | Role | Prioritas |
|---|---|---|---|
| POST | /auth/login | Publik | W |
| POST | /auth/logout | Semua yang login | W |
| GET | /auth/me | Semua yang login | W |
| POST | /auth/change-password | Semua yang login | S |
| POST | /auth/password-reset-requests | Publik | T |
| GET | /me/login-history | Semua yang login | T |
| GET, POST | /users | ADMIN | W |
| PATCH | /users/{id} | ADMIN | W |
| POST | /users/{id}/unlock | ADMIN | S |
| POST | /users/{id}/reset-password | ADMIN | S |
| GET | /password-reset-requests | ADMIN | T |
| GET | /sessions | ADMIN | S |
| POST | /sessions/{id}/terminate | ADMIN | S |
| GET | /activity-logs | ADMIN | W |
| GET | /notifications | Semua yang login | S |
| PATCH | /notifications/{id}/read, /notifications/read-all | Semua yang login | S |

**B: Order dan Pengiriman**

| Method | URL | Role | Prioritas |
|---|---|---|---|
| GET | /buyers | MARKETING, PIMPINAN | W |
| POST | /buyers | MARKETING | W |
| PATCH | /buyers/{id} | MARKETING | W |
| GET | /product-types, /items | MARKETING | W |
| POST | /orders | MARKETING | W |
| GET | /orders, /orders/{id} | MARKETING, PIMPINAN, PPIC, SPV, QC | W |
| POST | /orders/{id}/approve, /orders/{id}/reject | PIMPINAN | W |
| POST | /orders/{id}/cancel | PIMPINAN | W |
| POST | /orders/{id}/withdraw | MARKETING | T |
| GET | /price-history | MARKETING, PIMPINAN | T |
| GET | /dashboard | PIMPINAN | W |
| GET | /reports/production | PIMPINAN, PPIC | T |
| POST | /shipments | PPIC | W |
| GET | /shipments | PPIC, PIMPINAN | W |
| GET | /shipments/{id}/delivery-note | PPIC | W |
| POST | /shipments/{id}/signed-documents | PPIC | T |
| GET | /shipments/{id}/signed-documents | PIMPINAN, PPIC, MARKETING | T |

**C: Produksi**

| Method | URL | Role | Prioritas |
|---|---|---|---|
| GET | /suppliers | PPIC, PIMPINAN | W |
| POST | /suppliers | PPIC | W |
| PATCH | /suppliers/{id} | PPIC | W |
| GET | /suppliers/{id}/materials | PPIC, PIMPINAN | W |
| GET, POST | /order-styles/{styleId}/materials | PPIC | W |
| PATCH | /materials/{id} | PPIC | W |
| POST | /spk | PPIC | W |
| GET | /spk, /spk/{id} | PPIC, PIMPINAN, SPV, QC | W |
| POST | /spk/{id}/approve, /spk/{id}/reject | PIMPINAN | W |
| POST | /spk/{id}/progress | SPV | W |
| GET | /spk/{id}/progress | SPV, PPIC, PIMPINAN, QC | W |
| PATCH | /progress/{id} | SPV | W |
| POST | /spk/{id}/qc-results | QC | W |
| GET | /spk/{id}/qc-results | QC, PPIC, PIMPINAN | W |
| GET | /spk/{id}/print | PIMPINAN, PPIC, SPV | T |
| POST | /spk/{id}/signed-documents | PIMPINAN | T |
| GET | /spk/{id}/signed-documents | PIMPINAN, PPIC, SPV | T |
| GET | /signed-documents/{id}/file | Sesuai jenis dokumen | T |

Isi request dan response tiap endpoint ada di TSD 3.3 (kartu spesifikasi endpoint).

---

## 14. Halaman frontend dan pemiliknya

Path mengikuti FSD Bagian 3.

| SCR | Halaman | Path | Pemilik |
|---|---|---|---|
| SCR-01 | Login | /login | A |
| SCR-02 | Beranda | /beranda | A |
| SCR-03 | Manajemen Pengguna | /pengguna | A |
| SCR-19 | Ajukan Reset Password | /lupa-password | A |
| SCR-20 | Ganti Password | /ganti-password | A |
| SCR-21 | Riwayat Login Saya | /riwayat-login | A |
| SCR-22 | Sesi Aktif | /sesi | A |
| SCR-23 | Log Aktivitas | /log-aktivitas | A |
| SCR-24 | Notifikasi | /notifikasi | A |
| SCR-04 | Data Buyer | /buyer | B |
| SCR-05 | Formulir Order Baru | /order/baru | B |
| SCR-06 | Daftar dan Detail Order | /order | B |
| SCR-07 | Riwayat Harga | /riwayat-harga | B |
| SCR-08 | Persetujuan Order dan SPK | /persetujuan | B (bagian SPK dari C) |
| SCR-14 | Dashboard Pimpinan | /dashboard | B |
| SCR-15 | Rekap Produksi | /rekap | B |
| SCR-16 | Pengiriman | /pengiriman | B |
| SCR-17 | Surat Jalan (siap cetak) | /pengiriman/:id/surat-jalan | B |
| SCR-18 | Riwayat Pengiriman | /riwayat-pengiriman | B |
| SCR-09 | Supplier dan Bahan per Supplier | /supplier | C |
| SCR-10 | Bahan Baku per Style | /bahan-baku | C |
| SCR-11 | Surat Perintah Kerja | /spk | C |
| SCR-12 | Progres Harian | /progres | C |
| SCR-13 | Hasil QC | /qc | C |
| SCR-25 | SPK Siap Cetak dan Salinan | /spk/:id/cetak | C |

Aturan halaman:

1. Pakai komponen bersama buatan A: Button, Badge status, Table, Input, Modal, Alert (R-13).
2. Warna dan font hanya diambil dari token `@theme` di `index.css`.
3. Validasi form ditulis di `lib/validation.ts`, mengikuti kolom Constraint dan Validasi di FSD.
4. Setiap halaman menampilkan 4 kondisi: memuat, ada data, kosong, dan error dengan tombol Coba lagi (R-11).
5. Badge status menampilkan teks yang mudah dibaca, mis. `MENUNGGU_PERSETUJUAN` → "Menunggu Persetujuan". Fungsi pengubahnya dibuat A di `lib/format.ts`.

---

## 15. Perbedaan dengan TSD v1.1

Supaya bisa memakai kerangka kode praktikum, beberapa hal dibuat berbeda dari TSD v1.1. TSD perlu direvisi agar sama dengan daftar ini sebelum dikumpulkan.

| Hal | TSD v1.1 | Yang dipakai di kontrak ini | Alasan |
|---|---|---|---|
| Penyimpanan token | Header `Authorization: Bearer` | Cookie HttpOnly `token` | Mengikuti praktikum pertemuan 7 |
| Pencatatan log | Trigger `trg_audit_*` dengan SESSION_CONTEXT | Helper `logActivity()` di service, dalam transaksi | Lebih mudah dilacak, dan mencegah log tercatat dua kali. Trigger audit tidak dibuat |
| Pembuatan tabel | Migrasi Drizzle Kit | Skrip SQL ditulis tangan (`db/*.sql`); skema Drizzle hanya untuk query | Mengikuti praktikum; Drizzle untuk SQL Server masih beta |
| Frontend | Tailwind 3, TanStack Query, React Hook Form | Tailwind 4 (`@theme`), axios, validasi di `lib/validation.ts` | Mengikuti praktikum |
| Alamat Swagger | /api/docs | /docs | Mengikuti praktikum |
| Seed data | 6 akun, 3 buyer, 2 supplier | Sama, ditambah minimal 1 order DISETUJUI | Supaya C bisa langsung mencoba SPK (R-05) |

Bentuk response error tetap mengikuti TSD (`status: 'error'` dengan `error_code`), bukan format `fail` dari praktikum, supaya kode error FSD bisa langsung dipakai. Error handler dari praktikum cukup disesuaikan sekali oleh A.

---

## 16. Aturan Git

1. Setiap pagi: `git pull origin main`, lalu jalankan ulang skrip SQL kalau ada yang berubah.
2. Kerjakan di branch `feat/<nama-fitur>`, mis. `feat/order-approve`. Jangan langsung di `main`.
3. Setiap malam: buat Pull Request kecil untuk pekerjaan hari itu.
4. Satu anggota lain membaca PR itu dan memastikan nama serta formatnya sesuai kontrak ini, baru di-merge.
5. Jangan commit `.env`, `node_modules`, atau folder `uploads`.
6. Pesan commit singkat dan jelas, mis. `feat(order): endpoint setujui order` atau `fix(spk): cek status order`.

---

## 17. Riwayat perubahan kontrak

| Tanggal | Diubah oleh | Perubahan |
|---|---|---|
| 14/11/2026 | Kelompok 1 | Versi awal, disusun dari TSD v1.1, FSD v2.0, SRS v2.0, dan Rencana Kerja 14 Hari |
| 16/11/2026 | Kelompok 1 | Tambah Bagian 10.1: query tulis memakai `withTransaction()` + `sql.Transaction` (ikut pertemuan 9), query baca memakai Drizzle. Tambah `db/pool.ts` dan `utils/transaction.ts` di Bagian 7.1 |
