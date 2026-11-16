-- 01-core.sql (A) : roles, users, sessions, activity_logs, password_reset_requests, notifications
-- Jalankan dengan QUOTED_IDENTIFIER ON (default SSMS/DBeaver; untuk sqlcmd pakai opsi -I) karena ada filtered index.
USE solaris_db;
GO

CREATE TABLE roles (
    role_code   VARCHAR(10)  NOT NULL CONSTRAINT PK_roles PRIMARY KEY
                CONSTRAINT CK_roles_code CHECK (role_code IN ('ADMIN','PIMPINAN','MARKETING','PPIC','SPV','QC')),
    role_name   NVARCHAR(50) NOT NULL,
    access_tier VARCHAR(10)  NOT NULL
                CONSTRAINT CK_roles_tier CHECK (access_tier IN ('SUPERADMIN','ADMIN','USER'))
);
GO

CREATE TABLE users (
    id                   UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_users PRIMARY KEY CONSTRAINT DF_users_id DEFAULT NEWSEQUENTIALID(),
    full_name            NVARCHAR(100)    NOT NULL,
    username             VARCHAR(50)      NOT NULL CONSTRAINT UQ_users_username UNIQUE
                         CONSTRAINT CK_users_username CHECK (LEN(username) BETWEEN 4 AND 50),
    password_hash        VARCHAR(100)     NOT NULL,
    role_code            VARCHAR(10)      NOT NULL CONSTRAINT FK_users_role REFERENCES roles(role_code),
    is_active            BIT              NOT NULL CONSTRAINT DF_users_active DEFAULT 1,
    is_locked            BIT              NOT NULL CONSTRAINT DF_users_locked DEFAULT 0,
    failed_login_count   TINYINT          NOT NULL CONSTRAINT DF_users_failed DEFAULT 0,
    must_change_password BIT              NOT NULL CONSTRAINT DF_users_mcp DEFAULT 0,
    last_login_at        DATETIME2(0)     NULL,
    created_at           DATETIME2(0)     NOT NULL CONSTRAINT DF_users_created DEFAULT SYSDATETIME(),
    updated_at           DATETIME2(0)     NOT NULL CONSTRAINT DF_users_updated DEFAULT SYSDATETIME()
);
GO
CREATE INDEX IX_users_role_active ON users (role_code, is_active);
GO

CREATE TABLE sessions (
    id               UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_sessions PRIMARY KEY CONSTRAINT DF_sessions_id DEFAULT NEWSEQUENTIALID(),
    user_id          UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_sessions_user REFERENCES users(id),
    device           NVARCHAR(150)    NOT NULL,
    ip_address       VARCHAR(45)      NOT NULL,
    login_at         DATETIME2(0)     NOT NULL CONSTRAINT DF_sessions_login DEFAULT SYSDATETIME(),
    last_activity_at DATETIME2(0)     NOT NULL CONSTRAINT DF_sessions_last DEFAULT SYSDATETIME(),
    status           VARCHAR(10)      NOT NULL CONSTRAINT DF_sessions_status DEFAULT 'AKTIF'
                     CONSTRAINT CK_sessions_status CHECK (status IN ('AKTIF','BERAKHIR')),
    end_reason       VARCHAR(20)      NULL
                     CONSTRAINT CK_sessions_reason CHECK (end_reason IN ('LOGOUT','TIDAK_AKTIF','DIAKHIRI_ADMIN','RESET_PASSWORD','AKUN_NONAKTIF')),
    ended_at         DATETIME2(0)     NULL
);
GO
CREATE INDEX IX_sessions_user_status ON sessions (user_id, status);
CREATE INDEX IX_sessions_status_last ON sessions (status, last_activity_at);
GO

CREATE TABLE activity_logs (
    id            BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_activity_logs PRIMARY KEY,
    user_id       UNIQUEIDENTIFIER NULL CONSTRAINT FK_actlog_user REFERENCES users(id),
    username      VARCHAR(50)      NOT NULL,
    action_type   VARCHAR(20)      NOT NULL
                  CONSTRAINT CK_actlog_action CHECK (action_type IN (
                    'LOGIN_BERHASIL','LOGIN_GAGAL','LOGOUT','SESI_BERAKHIR','SESI_DIAKHIRI',
                    'AKUN_TERKUNCI','BUKA_KUNCI','RESET_PASSWORD','GANTI_PASSWORD','AKSES_DITOLAK',
                    'TAMBAH','UBAH','SETUJU','TOLAK','TARIK','BATAL','UNGGAH_DOKUMEN')),
    resource_type VARCHAR(30)      NULL,
    resource_id   VARCHAR(36)      NULL,
    old_values    NVARCHAR(MAX)    NULL CONSTRAINT CK_actlog_old CHECK (old_values IS NULL OR ISJSON(old_values) = 1),
    new_values    NVARCHAR(MAX)    NULL CONSTRAINT CK_actlog_new CHECK (new_values IS NULL OR ISJSON(new_values) = 1),
    device        NVARCHAR(150)    NULL,
    ip_address    VARCHAR(45)      NOT NULL,
    created_at    DATETIME2(0)     NOT NULL CONSTRAINT DF_actlog_created DEFAULT SYSDATETIME()
);
GO
CREATE INDEX IX_actlog_user_created ON activity_logs (user_id, created_at);
CREATE INDEX IX_actlog_created      ON activity_logs (created_at);
CREATE INDEX IX_actlog_action       ON activity_logs (action_type);
GO

CREATE TABLE password_reset_requests (
    id           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_pwreset PRIMARY KEY CONSTRAINT DF_pwreset_id DEFAULT NEWSEQUENTIALID(),
    user_id      UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_pwreset_user REFERENCES users(id),
    note         NVARCHAR(200)    NULL,
    status       VARCHAR(10)      NOT NULL CONSTRAINT DF_pwreset_status DEFAULT 'MENUNGGU'
                 CONSTRAINT CK_pwreset_status CHECK (status IN ('MENUNGGU','SELESAI')),
    handled_by   UNIQUEIDENTIFIER NULL CONSTRAINT FK_pwreset_handler REFERENCES users(id),
    requested_at DATETIME2(0)     NOT NULL CONSTRAINT DF_pwreset_req DEFAULT SYSDATETIME(),
    handled_at   DATETIME2(0)     NULL
);
GO
-- RB-61: satu permintaan MENUNGGU per akun
CREATE UNIQUE INDEX UX_pwreset_user_waiting ON password_reset_requests (user_id) WHERE status = 'MENUNGGU';
GO

CREATE TABLE notifications (
    id           UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_notifications PRIMARY KEY CONSTRAINT DF_notif_id DEFAULT NEWSEQUENTIALID(),
    recipient_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT FK_notif_user REFERENCES users(id),
    event_code   CHAR(4)          NOT NULL
                 CONSTRAINT CK_notif_event CHECK (event_code IN ('N-01','N-02','N-03','N-04','N-05','N-06','N-07','N-08','N-09','N-10','N-11','N-12','N-13')),
    message      NVARCHAR(300)    NOT NULL,
    link         VARCHAR(200)     NULL,
    dedup_key    VARCHAR(80)      NULL,
    is_read      BIT              NOT NULL CONSTRAINT DF_notif_read DEFAULT 0,
    created_at   DATETIME2(0)     NOT NULL CONSTRAINT DF_notif_created DEFAULT SYSDATETIME()
);
GO
CREATE INDEX IX_notif_recipient ON notifications (recipient_id, is_read, created_at);
CREATE UNIQUE INDEX UX_notif_dedup ON notifications (recipient_id, dedup_key) WHERE dedup_key IS NOT NULL;
GO
