CREATE TABLE messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sender VARCHAR(255) NOT NULL,
    receiver VARCHAR(255) NOT NULL,
    
    type ENUM('text', 'file') DEFAULT 'text',
    content TEXT,                -- sadece text mesajlarda dolu olur
    file_url TEXT,               -- sadece file mesajlarda dolu olur
    file_name VARCHAR(255),     -- dosya adı
    mime_type VARCHAR(255),     -- image/png, application/pdf vb.

    delivered BOOLEAN DEFAULT FALSE,  -- mesaj karşı tarafa ulaştı mı
    seen BOOLEAN DEFAULT FALSE,       -- mesaj görüldü mü
    seen_at DATETIME NULL,            -- ne zaman görüldü
    deleted BOOLEAN DEFAULT FALSE,    -- herkesten silindiyse

    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE deleted_messages (
    user VARCHAR(255) NOT NULL,
    message_id BIGINT NOT NULL,
    PRIMARY KEY (user, message_id),
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);
