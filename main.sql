-- Создание типа interpolation
DO $$ 
BEGIN
    DROP TYPE IF EXISTS interpolation;
    CREATE TYPE interpolation AS ENUM ('linear', 'spline');
END $$;


-- Создание последовательностей для всех таблиц
CREATE SEQUENCE IF NOT EXISTS military_ranks_seq START 3;
CREATE SEQUENCE IF NOT EXISTS employees_seq START 2;
CREATE SEQUENCE IF NOT EXISTS measurement_types_seq START 3;
CREATE SEQUENCE IF NOT EXISTS measurement_input_params_seq START 2;
CREATE SEQUENCE IF NOT EXISTS measurement_batches_seq START 2;
CREATE SEQUENCE IF NOT EXISTS temperature_corrections_seq START 1;

-- Справочник должностей
CREATE TABLE IF NOT EXISTS military_ranks (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('military_ranks_seq'),
    description CHARACTER VARYING(255) NOT NULL
);

-- Таблица пользователей
CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('employees_seq'),
    name TEXT NOT NULL,
    birthday TIMESTAMP,
    military_rank_id INTEGER REFERENCES military_ranks(id) ON DELETE SET NULL
);

-- Таблица типов измерений
CREATE TABLE IF NOT EXISTS measurement_types (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('measurement_types_seq'),
    short_name CHARACTER VARYING(50) NOT NULL,
    description TEXT NOT NULL
);

-- Таблица с параметрами измерений
CREATE TABLE IF NOT EXISTS measurement_input_params (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('measurement_input_params_seq'),
    measurement_type_id INTEGER NOT NULL REFERENCES measurement_types(id) ON DELETE CASCADE,
    height NUMERIC(8,2) DEFAULT 0,
    temperature NUMERIC(8,2) DEFAULT 0,
    pressure NUMERIC(8,2) DEFAULT 0,
    wind_direction NUMERIC(8,2) DEFAULT 0,
    wind_speed NUMERIC(8,2) DEFAULT 0
);

-- Таблица истории измерений
CREATE TABLE IF NOT EXISTS measurement_batches (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('measurement_batches_seq'),
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    measurement_input_param_id INTEGER NOT NULL REFERENCES measurement_input_params(id) ON DELETE CASCADE,
    started TIMESTAMP DEFAULT now()
);

-- Таблица поправок по температуре (согласно Таблице 1)
CREATE TABLE IF NOT EXISTS temperature_corrections (
    id INTEGER PRIMARY KEY NOT NULL DEFAULT nextval('temperature_corrections_seq'),
    temperature DECIMAL NOT NULL UNIQUE,
    correction DECIMAL NOT NULL
);

-- Вставка данных в temperature_corrections, если таблица пустая
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM temperature_corrections) THEN
        INSERT INTO temperature_corrections (temperature, correction) VALUES
        (0, 0.0),
        (5, 0.5),
        (10, 1.0),
        (15, 1.5),
        (20, 1.5),
        (25, 2.0),
        (30, 3.5),
        (40, 4.5);
    END IF;
END $$;


-- Функция интерполяции для расчёта поправки к температуре
CREATE OR REPLACE FUNCTION get_temperature_correction(temp DECIMAL)
RETURNS DECIMAL AS $$
DECLARE
    lower_temp DECIMAL;
    upper_temp DECIMAL;
    lower_corr DECIMAL;
    upper_corr DECIMAL;
    correction DECIMAL;
BEGIN
    -- Получаем нижнюю границу диапазона
    SELECT temperature, correction INTO lower_temp, lower_corr
    FROM temperature_corrections
    WHERE temperature <= temp
    ORDER BY temperature DESC
    LIMIT 1;

    -- Получаем верхнюю границу диапазона
    SELECT temperature, correction INTO upper_temp, upper_corr
    FROM temperature_corrections
    WHERE temperature >= temp
    ORDER BY temperature ASC
    LIMIT 1;

    -- Если температура ниже минимальной, вернуть первую поправку
    IF lower_temp IS NULL THEN
        RETURN upper_corr;
    END IF;

    -- Если температура выше максимальной, вернуть последнюю поправку
    IF upper_temp IS NULL THEN
        RETURN lower_corr;
    END IF;

    -- Если температура совпадает с одной из точек, вернуть точное значение
    IF temp = lower_temp THEN
        RETURN lower_corr;
    ELSIF temp = upper_temp THEN
        RETURN upper_corr;
    ELSE
        -- Линейная интерполяция между соседними значениями
        correction := lower_corr + (upper_corr - lower_corr) * (temp - lower_temp) / (upper_temp - lower_temp);
        RETURN correction;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для формирования кода в формате ДДЧЧМ
CREATE OR REPLACE FUNCTION get_detailed_measurement_code() 
RETURNS TEXT AS $$
DECLARE
    day INTEGER;
    hour INTEGER;
    minute INTEGER;
BEGIN
    -- Получаем текущую системную дату и время
    SELECT EXTRACT(DAY FROM now()), EXTRACT(HOUR FROM now()), EXTRACT(MINUTE FROM now()) INTO day, hour, minute;

    -- Формируем код в формате ДДЧЧМ
    RETURN LPAD(day::TEXT, 2, '0') || LPAD(hour::TEXT, 2, '0') || LPAD(minute::TEXT, 2, '0');
END;
$$ LANGUAGE plpgsql;

-- Функция для вычисления высоты метеопоста
CREATE OR REPLACE FUNCTION get_measurement_post_height() 
RETURNS TEXT AS $$
DECLARE
    height INTEGER;
BEGIN
    -- Получаем данные о высоте метеопоста
    SELECT height INTO height FROM measurement_input_params LIMIT 1;

    -- Формируем код в формате ВВВВ
    RETURN LPAD(height::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- Функция для вычисления отклонения давления
CREATE OR REPLACE FUNCTION get_pressure_deviation()
RETURNS TEXT AS $$
DECLARE
    pressure DECIMAL;
    deviation DECIMAL;
BEGIN
    -- Получаем данные о давлении
    SELECT pressure INTO pressure FROM measurement_input_params LIMIT 1;

    -- Отклонение давления от табличного значения 750 мм рт. ст.
    deviation := pressure - 750;

    -- Формируем код в формате БББТТ
    IF deviation > 0 THEN
        RETURN LPAD(deviation::TEXT, 3, '0');
    ELSE
        RETURN LPAD((500 - deviation)::TEXT, 3, '0');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для вычисления отклонения температуры
CREATE OR REPLACE FUNCTION get_temperature_deviation()
RETURNS TEXT AS $$
DECLARE
    temperature DECIMAL;
    deviation DECIMAL;
BEGIN
    -- Получаем данные о температуре
    SELECT temperature INTO temperature FROM measurement_input_params LIMIT 1;

    -- Отклонение температуры от табличного значения 15,9°C
    deviation := temperature - 15.9;

    -- Формируем код в формате ТТ
    RETURN LPAD(deviation::TEXT, 2, '0');
END;
$$ LANGUAGE plpgsql;

-- Создание таблицы настроек для проверки входных данных
CREATE TABLE IF NOT EXISTS measure_settings (
    id SERIAL PRIMARY KEY,
    min_temperature DECIMAL DEFAULT -58,
    max_temperature DECIMAL DEFAULT 58,
    min_pressure DECIMAL DEFAULT 500,
    max_pressure DECIMAL DEFAULT 900,
    min_wind_direction DECIMAL DEFAULT 0,
    max_wind_direction DECIMAL DEFAULT 59
);

-- Функция для проверки входных параметров
CREATE OR REPLACE FUNCTION validate_measurement_params(
    p_temperature DECIMAL, 
    p_pressure DECIMAL, 
    p_wind_direction DECIMAL
) 
RETURNS VOID AS $$
BEGIN
    -- Проверка температуры
    IF p_temperature < (SELECT min_temperature FROM measure_settings) OR p_temperature > (SELECT max_temperature FROM measure_settings) THEN
        RAISE EXCEPTION 'Temperature out of bounds: %', p_temperature;
    END IF;

    -- Проверка давления
    IF p_pressure < (SELECT min_pressure FROM measure_settings) OR p_pressure > (SELECT max_pressure FROM measure_settings) THEN
        RAISE EXCEPTION 'Pressure out of bounds: %', p_pressure;
    END IF;

    -- Проверка направления ветра
    IF p_wind_direction < (SELECT min_wind_direction FROM measure_settings) OR p_wind_direction > (SELECT max_wind_direction FROM measure_settings) THEN
        RAISE EXCEPTION 'Wind direction out of bounds: %', p_wind_direction;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Добавление записей в таблицу military_ranks
INSERT INTO military_ranks (id, description) 
VALUES (1, 'Рядовой'), (2, 'Лейтенант');

