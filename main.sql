-- Создание типа interpolation, если он не существует
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interpolation') THEN
        CREATE TYPE interpolation AS ENUM ('linear', 'spline');
    END IF;
END $$;

-- Справочник должностей
CREATE TABLE IF NOT EXISTS military_ranks (
    id INTEGER PRIMARY KEY NOT NULL,
    description CHARACTER VARYING(255) NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS military_ranks_seq START 3;
ALTER TABLE military_ranks ALTER COLUMN id SET DEFAULT nextval('public.military_ranks_seq');

-- Таблица пользователей
CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    birthday TIMESTAMP,
    military_rank_id INTEGER REFERENCES military_ranks(id) ON DELETE SET NULL
);

CREATE SEQUENCE IF NOT EXISTS employees_seq START 2;
ALTER TABLE employees ALTER COLUMN id SET DEFAULT nextval('public.employees_seq');

-- Таблица типов измерений
CREATE TABLE IF NOT EXISTS measurement_types (
    id INTEGER PRIMARY KEY NOT NULL,
    short_name CHARACTER VARYING(50) NOT NULL,
    description TEXT NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS measurement_types_seq START 3;
ALTER TABLE measurement_types ALTER COLUMN id SET DEFAULT nextval('public.measurement_types_seq');

-- Таблица с параметрами измерений
CREATE TABLE IF NOT EXISTS measurement_input_params (
    id INTEGER PRIMARY KEY NOT NULL,
    measurement_type_id INTEGER NOT NULL REFERENCES measurement_types(id) ON DELETE CASCADE,
    height NUMERIC(8,2) DEFAULT 0,
    temperature NUMERIC(8,2) DEFAULT 0,
    pressure NUMERIC(8,2) DEFAULT 0,
    wind_direction NUMERIC(8,2) DEFAULT 0,
    wind_speed NUMERIC(8,2) DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS measurement_input_params_seq START 2;
ALTER TABLE measurement_input_params ALTER COLUMN id SET DEFAULT nextval('public.measurement_input_params_seq');

-- Таблица истории измерений
CREATE TABLE IF NOT EXISTS measurement_batches (
    id INTEGER PRIMARY KEY NOT NULL,
    employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    measurement_input_param_id INTEGER NOT NULL REFERENCES measurement_input_params(id) ON DELETE CASCADE,
    started TIMESTAMP DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS measurement_batches_seq START 2;
ALTER TABLE measurement_batches ALTER COLUMN id SET DEFAULT nextval('public.measurement_batches_seq');

-- Таблица поправок по температуре (согласно Таблице 1)
CREATE TABLE IF NOT EXISTS temperature_corrections (
    id SERIAL PRIMARY KEY,
    temperature DECIMAL NOT NULL UNIQUE,
    correction DECIMAL NOT NULL
);

-- Вставка данных в temperature_corrections, если таблица пустая
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM temperature_corrections) THEN
        INSERT INTO temperature_corrections (temperature, correction) VALUES
        (-1, 0.0),  -- Для значений ниже 0
        (0, 0.0),
        (5, 0.5),
        (10, 1.0),
        (15, 1.5),
        (20, 1.5),
        (25, 2.0),
        (30, 3.5),
        (40, 4.5),
        (41, 4.5); -- Для значений выше 40
    END IF;
END $$;

-- Функция интерполяции для расчёта поправки к температуре (с учетом Таблицы 1)
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
