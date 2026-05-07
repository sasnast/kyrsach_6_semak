
-- =====================================================
-- 1. УДАЛЕНИЕ СТАРЫХ ТАБЛИЦ 
-- =====================================================
DROP TABLE IF EXISTS appointment_extra_services CASCADE;
DROP TABLE IF EXISTS appointment_services CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS extra_services CASCADE;
DROP TABLE IF EXISTS prices CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS masters CASCADE;
DROP TABLE IF EXISTS master_levels CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- =====================================================
-- 2. ТАБЛИЦА РОЛЕЙ
-- =====================================================
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

COMMENT ON TABLE roles IS 'Роли пользователей (администратор, клиент)';

-- =====================================================
-- 3. ТАБЛИЦА КЛИЕНТОВ
-- =====================================================
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE clients IS 'Клиенты студии';

-- =====================================================
-- 4. ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ
-- =====================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role_id INT REFERENCES roles(id),
    client_id INT REFERENCES clients(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS 'Пользователи системы (авторизация)';

-- =====================================================
-- 5. ТАБЛИЦА УРОВНЕЙ МАСТЕРОВ
-- =====================================================
CREATE TABLE master_levels (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    coefficient DECIMAL(3,2) DEFAULT 1.00
);

COMMENT ON TABLE master_levels IS 'Уровни мастеров (Мастер, Мастер+, PRO)';

-- =====================================================
-- 6. ТАБЛИЦА МАСТЕРОВ
-- =====================================================
CREATE TABLE masters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    level_id INT REFERENCES master_levels(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE masters IS 'Сотрудники-мастера';

-- =====================================================
-- 7. ТАБЛИЦА УСЛУГ
-- =====================================================
CREATE TABLE services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    duration_minutes INT DEFAULT 60,
    is_active BOOLEAN DEFAULT true
);

COMMENT ON TABLE services IS 'Основные услуги студии';

-- =====================================================
-- 8. ТАБЛИЦА ЦЕН
-- =====================================================
CREATE TABLE prices (
    id SERIAL PRIMARY KEY,
    service_id INT REFERENCES services(id) ON DELETE CASCADE,
    level_id INT REFERENCES master_levels(id),
    price DECIMAL(10,2) NOT NULL,
    UNIQUE(service_id, level_id)
);

COMMENT ON TABLE prices IS 'Цены на услуги в зависимости от уровня мастера';

-- =====================================================
-- 9. ТАБЛИЦА ДОПОЛНИТЕЛЬНЫХ УСЛУГ
-- =====================================================
CREATE TABLE extra_services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    duration_minutes INT DEFAULT 30,
    is_active BOOLEAN DEFAULT true
);

COMMENT ON TABLE extra_services IS 'Дополнительные услуги (дизайн, укрепление и т.д.)';

-- =====================================================
-- 10. ТАБЛИЦА ЗАПИСЕЙ
-- =====================================================
CREATE TABLE appointments (
    id SERIAL PRIMARY KEY,
    client_id INT REFERENCES clients(id),
    master_id INT REFERENCES masters(id),
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) DEFAULT 'Запланирована',
    total_price DECIMAL(10,2) DEFAULT 0,
    discount_applied INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(master_id, appointment_date, appointment_time)
);

COMMENT ON TABLE appointments IS 'Записи клиентов на услуги';

-- =====================================================
-- 11. ТАБЛИЦА УСЛУГ В ЗАПИСИ
-- =====================================================
CREATE TABLE appointment_services (
    id SERIAL PRIMARY KEY,
    appointment_id INT REFERENCES appointments(id) ON DELETE CASCADE,
    service_id INT REFERENCES services(id)
);

COMMENT ON TABLE appointment_services IS 'Основные услуги, включённые в запись';

-- =====================================================
-- 12. ТАБЛИЦА ДОП. УСЛУГ В ЗАПИСИ
-- =====================================================
CREATE TABLE appointment_extra_services (
    id SERIAL PRIMARY KEY,
    appointment_id INT REFERENCES appointments(id) ON DELETE CASCADE,
    extra_service_id INT REFERENCES extra_services(id)
);

COMMENT ON TABLE appointment_extra_services IS 'Дополнительные услуги, включённые в запись';

-- =====================================================
-- 13. ТАБЛИЦА ОТЗЫВОВ И РЕЙТИНГОВ
-- =====================================================
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    master_id INT REFERENCES masters(id) ON DELETE CASCADE,
    client_id INT REFERENCES clients(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE reviews IS 'Отзывы клиентов о мастерах';

CREATE INDEX idx_reviews_master_id ON reviews(master_id);
CREATE INDEX idx_reviews_client_id ON reviews(client_id);

-- =====================================================
-- 14. ТАБЛИЦА АКЦИЙ
-- =====================================================
CREATE TABLE promotions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    discount_percent INT NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
    promotion_type VARCHAR(50) DEFAULT 'standard',
    start_date DATE,
    end_date DATE,
    start_time TIME,
    end_time TIME,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE promotions IS 'Акции и скидочные предложения';

-- =====================================================
-- 15. ФУНКЦИЯ РАСЧЕТА МАКСИМАЛЬНОЙ СКИДКИ
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_max_discount(
    p_client_id INT,
    p_appointment_date DATE,
    p_appointment_time TIME
)
RETURNS DECIMAL AS $$
DECLARE
    v_discount DECIMAL := 0;
    v_new_client_discount DECIMAL := 0;
    v_happy_hours_discount DECIMAL := 0;
    v_seasonal_discount DECIMAL := 0;
    v_existing_appointments INT;
BEGIN
    -- Количество существующих записей клиента
    SELECT COUNT(*) INTO v_existing_appointments 
    FROM appointments 
    WHERE client_id = p_client_id;
    
    -- 1. Акция для нового клиента
    IF v_existing_appointments = 0 THEN
        SELECT discount_percent INTO v_new_client_discount
        FROM promotions 
        WHERE promotion_type = 'new_client' AND is_active = true;
    END IF;
    
    -- 2. Счастливые часы
    IF p_appointment_time >= '09:00:00' AND p_appointment_time < '12:00:00' THEN
        SELECT discount_percent INTO v_happy_hours_discount
        FROM promotions 
        WHERE promotion_type = 'happy_hours' AND is_active = true;
    END IF;
    
    -- 3. Сезонная акция
    SELECT discount_percent INTO v_seasonal_discount
    FROM promotions 
    WHERE promotion_type = 'seasonal' 
      AND is_active = true
      AND start_date <= p_appointment_date 
      AND end_date >= p_appointment_date;
    
    -- Выбираем МАКСИМАЛЬНУЮ скидку
    v_discount := GREATEST(
        COALESCE(v_new_client_discount, 0),
        COALESCE(v_happy_hours_discount, 0),
        COALESCE(v_seasonal_discount, 0)
    );
    
    RETURN v_discount;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_max_discount IS 'Возвращает максимальную скидку для клиента на основании типа акции';

-- =====================================================
-- 16. ТРИГГЕР ПРИМЕНЕНИЯ СКИДКИ ПЕРЕД ВСТАВКОЙ
-- =====================================================
CREATE OR REPLACE FUNCTION apply_discount_before_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_discount DECIMAL;
BEGIN
    IF NEW.total_price IS NOT NULL AND NEW.total_price > 0 THEN
        v_discount := calculate_max_discount(NEW.client_id, NEW.appointment_date, NEW.appointment_time);
        
        IF v_discount > 0 THEN
            NEW.total_price := NEW.total_price * (1 - v_discount / 100);
            NEW.discount_applied := v_discount;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION apply_discount_before_insert IS 'Триггерная функция: применяет максимальную скидку перед вставкой записи';

DROP TRIGGER IF EXISTS trg_apply_discount_before_insert ON appointments;
CREATE TRIGGER trg_apply_discount_before_insert
    BEFORE INSERT ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION apply_discount_before_insert();

COMMENT ON TRIGGER trg_apply_discount_before_insert ON appointments IS 'Триггер для автоматического применения скидки при создании записи';

-- =====================================================
-- 17. НАЧАЛЬНЫЕ ДАННЫЕ (РОЛИ, УРОВНИ, УСЛУГИ, МАСТЕРА, АКЦИИ)
-- =====================================================

-- Роли
INSERT INTO roles (name) VALUES ('admin'), ('client')
ON CONFLICT (name) DO NOTHING;

-- Уровни мастеров
INSERT INTO master_levels (name, coefficient) VALUES
('Мастер', 1.0),
('Мастер+', 1.2),
('PRO', 1.5)
ON CONFLICT (name) DO NOTHING;

-- Мастера
INSERT INTO masters (name, phone, level_id) VALUES
('Александра', '+79111111111', 1),
('Елена', '+79222222222', 2),
('Ксения', '+79333333333', 3),
('Виктория', '+79444444444', 2),
('Дарья', '+79555555555', 1)
ON CONFLICT DO NOTHING;

-- Основные услуги
INSERT INTO services (name, description, duration_minutes) VALUES
('Маникюр без покрытия', 'Классический маникюр', 45),
('Маникюр с покрытием', 'Маникюр с гель-лаком', 90),
('Наращивание ногтей', 'Наращивание акригелем', 120),
('Педикюр', 'Классический педикюр', 90),
('СПА педикюр', 'Педикюр с SPA-уходом', 120)
ON CONFLICT DO NOTHING;

-- Цены на услуги (service_id, level_id, price)
INSERT INTO prices (service_id, level_id, price) VALUES
(1,1,800),   (1,2,1000),  (1,3,1200),
(2,1,1400),  (2,2,1700),  (2,3,2000),
(3,1,2200),  (3,2,2600),  (3,3,3000),
(4,1,1200),  (4,2,1500),  (4,3,1800),
(5,1,2000),  (5,2,2400),  (5,3,2800)
ON CONFLICT (service_id, level_id) DO NOTHING;

-- Дополнительные услуги
INSERT INTO extra_services (name, price, duration_minutes) VALUES
('Ремонт ногтя', 150, 15),
('Укрепление гелем', 400, 30),
('Дизайн (1 ноготь)', 150, 10)
ON CONFLICT DO NOTHING;

-- Акции
INSERT INTO promotions (name, discount_percent, promotion_type, start_time, end_time, is_active) VALUES
('Счастливые часы', 20, 'happy_hours', '09:00:00', '12:00:00', true)
ON CONFLICT DO NOTHING;

INSERT INTO promotions (name, discount_percent, promotion_type, start_date, end_date, is_active) VALUES
('Весенняя распродажа', 25, 'seasonal', '2026-04-25', '2026-05-25', true)
ON CONFLICT DO NOTHING;

INSERT INTO promotions (name, discount_percent, promotion_type, is_active) VALUES
('Новым клиентам', 15, 'new_client', true)
ON CONFLICT DO NOTHING;

-- Тестовый администратор (пароль: admin123)
INSERT INTO clients (name, phone) VALUES ('Администратор', '+70000000000')
ON CONFLICT DO NOTHING;

INSERT INTO users (login, password, role_id, client_id) 
SELECT 'admin', '$2b$10$91kLJqM7K7yGQqZQZQZQZQ', 1, id 
FROM clients WHERE name = 'Администратор'
ON CONFLICT (login) DO NOTHING;

CREATE OR REPLACE VIEW active_promotions_view AS
SELECT 
    id,
    name,
    discount_percent,
    promotion_type,
    CASE 
        WHEN promotion_type = 'happy_hours' THEN CONCAT('⏰ ', start_time, ' — ', end_time)
        WHEN promotion_type = 'seasonal' THEN CONCAT('📅 ', to_char(start_date, 'DD.MM.YYYY'), ' — ', to_char(end_date, 'DD.MM.YYYY'))
        WHEN promotion_type = 'new_client' THEN '🆕 Для новых клиентов'
        ELSE '📌 На все услуги'
    END as condition_description,
    is_active
FROM promotions
WHERE is_active = true
ORDER BY discount_percent DESC;

COMMENT ON VIEW active_promotions_view IS 'Актуальные акции с человекочитаемым описанием условий';
CREATE OR REPLACE VIEW master_statistics_view AS
SELECT 
    m.id,
    m.name,
    ml.name as level_name,
    COUNT(DISTINCT a.id) as total_appointments,
    COUNT(DISTINCT r.id) as total_reviews,
    COALESCE(AVG(r.rating), 0) as average_rating,
    COALESCE(SUM(a.total_price), 0) as total_revenue
FROM masters m
LEFT JOIN master_levels ml ON m.level_id = ml.id
LEFT JOIN appointments a ON m.id = a.master_id
LEFT JOIN reviews r ON m.id = r.master_id
GROUP BY m.id, m.name, ml.name
ORDER BY average_rating DESC, total_appointments DESC;

COMMENT ON VIEW master_statistics_view IS 'Сводная статистика по мастерам: записи, отзывы, рейтинг, выручка';
CREATE OR REPLACE FUNCTION get_master_workload(
    p_master_id INT,
    p_date DATE
)
RETURNS TABLE(
    hour TIME,
    is_booked BOOLEAN,
    client_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        h.hour::TIME,
        CASE WHEN a.id IS NOT NULL THEN true ELSE false END as is_booked,
        a.client_name
    FROM (
        SELECT generate_series('09:00:00'::TIME, '20:00:00'::TIME, '1 hour'::INTERVAL) as hour
    ) h
    LEFT JOIN (
        SELECT a.appointment_time, c.name as client_name, a.id
        FROM appointments a
        JOIN clients c ON a.client_id = c.id
        WHERE a.master_id = p_master_id AND a.appointment_date = p_date
    ) a ON a.appointment_time = h.hour
    ORDER BY h.hour;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_master_workload IS 'Возвращает расписание мастера на конкретную дату (почасово)';
CREATE OR REPLACE FUNCTION calculate_revenue(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS DECIMAL AS $$
DECLARE
    v_total DECIMAL;
BEGIN
    SELECT COALESCE(SUM(total_price), 0)
    INTO v_total
    FROM appointments
    WHERE status = 'Выполнена' 
      AND appointment_date BETWEEN p_start_date AND p_end_date;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_revenue IS 'Рассчитывает общую выручку за указанный период';
CREATE OR REPLACE FUNCTION get_popular_services(
    p_limit INT DEFAULT 5
)
RETURNS TABLE(
    service_name VARCHAR,
    times_ordered INT,
    total_revenue DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.name,
        COUNT(app_s.id) as times_ordered,
        COALESCE(SUM(p.price), 0) as total_revenue
    FROM services s
    JOIN appointment_services app_s ON s.id = app_s.service_id
    JOIN appointments a ON app_s.appointment_id = a.id
    JOIN prices p ON p.service_id = s.id
    WHERE a.status = 'Выполнена'
    GROUP BY s.id, s.name
    ORDER BY times_ordered DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_popular_services IS 'Возвращает топ-N самых популярных услуг';
-- Функция для автообновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер на таблицу reviews
DROP TRIGGER IF EXISTS trg_reviews_updated_at ON reviews;
CREATE TRIGGER trg_reviews_updated_at
    BEFORE UPDATE ON reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TRIGGER trg_reviews_updated_at ON reviews IS 'Автоматически обновляет поле updated_at при изменении отзыва';
