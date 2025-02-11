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
    description CHARACTER VARYING(255)
);

CREATE SEQUENCE IF NOT EXISTS military_ranks_seq START 3;
ALTER TABLE military_ranks ALTER COLUMN id SET DEFAULT nextval('public.military_ranks_seq');

-- Вставка данных, если их нет
INSERT INTO military_ranks(id, description)
SELECT 1, 'Рядовой' WHERE NOT EXISTS (SELECT 1 FROM military_ranks WHERE id = 1);
INSERT INTO military_ranks(id, description)
SELECT 2, 'Лейтенант' WHERE NOT EXISTS (SELECT 1 FROM military_ranks WHERE id = 2);

-- Таблица пользователей
CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY NOT NULL,
    name TEXT,
    birthday TIMESTAMP,
    military_rank_id INTEGER
);

CREATE SEQUENCE IF NOT EXISTS employees_seq START 2;
ALTER TABLE employees ALTER COLUMN id SET DEFAULT nextval('public.employees_seq');

INSERT INTO employees(id, name, birthday, military_rank_id)
SELECT 1, 'Воловиков Александр Сергеевич', '1978-06-24', 2
WHERE NOT EXISTS (SELECT 1 FROM employees WHERE id = 1);

-- Таблица типов устройств для измерения
CREATE TABLE IF NOT EXISTS measurment_types (
    id INTEGER PRIMARY KEY NOT NULL,
    short_name CHARACTER VARYING(50),
    description TEXT
);

CREATE SEQUENCE IF NOT EXISTS measurment_types_seq START 3;
ALTER TABLE measurment_types ALTER COLUMN id SET DEFAULT nextval('public.measurment_types_seq');

INSERT INTO measurment_types(id, short_name, description)
SELECT 1, 'ДМК', 'Десантный метео комплекс'
WHERE NOT EXISTS (SELECT 1 FROM measurment_types WHERE id = 1);
INSERT INTO measurment_types(id, short_name, description)
SELECT 2, 'ВР', 'Ветровое ружье'
WHERE NOT EXISTS (SELECT 1 FROM measurment_types WHERE id = 2);

-- Таблица с параметрами измерений
CREATE TABLE IF NOT EXISTS measurment_input_params (
    id INTEGER PRIMARY KEY NOT NULL,
    measurment_type_id INTEGER NOT NULL,
    height NUMERIC(8,2) DEFAULT 0,
    temperature NUMERIC(8,2) DEFAULT 0,
    pressure NUMERIC(8,2) DEFAULT 0,
    wind_direction NUMERIC(8,2) DEFAULT 0,
    wind_speed NUMERIC(8,2) DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS measurment_input_params_seq START 2;
ALTER TABLE measurment_input_params ALTER COLUMN id SET DEFAULT nextval('public.measurment_input_params_seq');

INSERT INTO measurment_input_params(id, measurment_type_id, height, temperature, pressure, wind_direction, wind_speed)
SELECT 1, 1, 100, 12, 34, 0.2, 45
WHERE NOT EXISTS (SELECT 1 FROM measurment_input_params WHERE id = 1);

-- Таблица истории измерений
CREATE TABLE IF NOT EXISTS measurment_baths (
    id INTEGER PRIMARY KEY NOT NULL,
    emploee_id INTEGER NOT NULL,
    measurment_input_param_id INTEGER NOT NULL,
    started TIMESTAMP DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS measurment_baths_seq START 2;
ALTER TABLE measurment_baths ALTER COLUMN id SET DEFAULT nextval('public.measurment_baths_seq');

INSERT INTO measurment_baths(id, emploee_id, measurment_input_param_id)
SELECT 1, 1, 1 WHERE NOT EXISTS (SELECT 1 FROM measurment_baths WHERE id = 1);

-- Таблица поправок по температуре
CREATE TABLE IF NOT EXISTS temperature_corrections (
    id SERIAL PRIMARY KEY,
    temperature DECIMAL NOT NULL UNIQUE,
    correction DECIMAL NOT NULL
);

-- Вставка данных, если таблица пустая
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM temperature_corrections) THEN
        INSERT INTO temperature_corrections (temperature, correction) VALUES
        (-40, -5.0),
        (-30, -4.0),
        (-20, -3.0),
        (-10, -2.0),
        (0, -1.0),
        (10, 0.0),
        (20, 1.0),
        (30, 2.0),
        (40, 3.0);
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
    -- Получаем соседние точки для интерполяции
    SELECT temperature, correction INTO lower_temp, lower_corr
    FROM temperature_corrections
    WHERE temperature <= temp
    ORDER BY temperature DESC
    LIMIT 1;

    SELECT temperature, correction INTO upper_temp, upper_corr
    FROM temperature_corrections
    WHERE temperature >= temp
    ORDER BY temperature ASC
    LIMIT 1;

    -- Если температура совпадает с одной из точек, возвращаем поправку напрямую
    IF temp = lower_temp THEN
        RETURN lower_corr;
    ELSIF temp = upper_temp THEN
        RETURN upper_corr;
    ELSE
        -- Линейная интерполяция
        correction := lower_corr + (upper_corr - lower_corr) * (temp - lower_temp) / (upper_temp - lower_temp);
        RETURN correction;
    END IF;
END;
$$ LANGUAGE plpgsql;
