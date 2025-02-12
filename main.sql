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