-- 90-seed-core.sql (A) : 6 role + 6 akun demo (password semua: Solaris#2026)
USE solaris_db;
GO
INSERT INTO roles (role_code, role_name, access_tier) VALUES
 ('ADMIN',    N'Administrator Sistem', 'SUPERADMIN'),
 ('PIMPINAN', N'Pimpinan',             'ADMIN'),
 ('MARKETING',N'Marketing',            'USER'),
 ('PPIC',     N'PPIC',                 'USER'),
 ('SPV',      N'Supervisor',           'USER'),
 ('QC',       N'Quality Control',      'USER');
GO
INSERT INTO users (full_name, username, password_hash, role_code) VALUES
 (N'Administrator Solaris', 'admin.solaris', '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'ADMIN'),
 (N'Pimpinan Solaris',      'pimpinan',      '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'PIMPINAN'),
 (N'Marketing Solaris',     'marketing',     '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'MARKETING'),
 (N'PPIC Solaris',          'ppic',          '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'PPIC'),
 (N'Supervisor Solaris',    'supervisor',    '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'SPV'),
 (N'Quality Control Solaris','qc.solaris',   '$2a$12$tvcyVNxaE5.4BbCOnPhQpekypTFjEBf0dWOjY5f6zS9Zxy37OJ7xi', 'QC');
GO
