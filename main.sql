-- Создание типа interpolation
DO $$ 
BEGIN
    DROP TYPE IF EXISTS interpolation CASCADE;
    CREATE TYPE interpolation AS ENUM ('linear', 'spline');
END $$;

-- Создание составного типа для параметров измерений
DO $$
BEGIN
    DROP TYPE IF EXISTS measurement_params CASCADE;
    CREATE TYPE measurement_params AS (
        height NUMERIC(8,2),
        temperature NUMERIC(8,2),
        pressure NUMERIC(8,2),
        wind_direction NUMERIC(8,2),
        wind_speed NUMERIC(8,2)
    );
END $$;

-- Создание последовательностей для всех таблиц
CREATE SEQUENCE IF NOT EXISTS military_ranks_seq START 3;
CREATE SEQUENCE IF NOT EXISTS employees_seq START 2;
CREATE SEQUENCE IF NOT EXISTS measurement_types_seq START 3;
CREATE SEQUENCE IF NOT EXISTS measurement_input_params_seq START 2;
CREATE SEQUENCE IF NOT EXISTS measurement_batches_seq START 2;
CREATE SEQUENCE IF NOT EXISTS temperature_corrections_seq START 1;

-- Создание таблицы настроек для проверки входных данных
CREATE TABLE IF NOT EXISTS measure_settings (
    id SERIAL PRIMARY KEY,
    min_temperature DECIMAL DEFAULT -58,    -- Минимальная температура
    max_temperature DECIMAL DEFAULT 58,     -- Максимальная температура
    min_pressure DECIMAL DEFAULT 500,       -- Минимальное давление
    max_pressure DECIMAL DEFAULT 900,       -- Максимальное давление
    min_wind_direction DECIMAL DEFAULT 0,   -- Минимальное направление ветра
    max_wind_direction DECIMAL DEFAULT 59,  -- Максимальное направление ветра
    min_wind_speed DECIMAL DEFAULT 0,       -- Минимальная скорость ветра
    max_wind_speed DECIMAL DEFAULT 20,      -- Максимальная скорость ветра
    min_height DECIMAL DEFAULT 0,           -- Минимальная высота
    max_height DECIMAL DEFAULT 200,         -- Максимальная высота
    constant_value DECIMAL DEFAULT 750,     -- Константное значение (750)
    additional_constant DECIMAL DEFAULT 15.9, -- Дополнительная константа (15.9)
    CONSTRAINT measure_settings_single_record CHECK (id = 1)  -- Ограничение на одну запись
);

-- Вставка настроек по умолчанию, если таблица пуста
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM measure_settings) THEN
        INSERT INTO measure_settings (
            min_temperature, max_temperature,
            min_pressure, max_pressure,
            min_wind_direction, max_wind_direction,
            min_wind_speed, max_wind_speed,
            min_height, max_height,
            constant_value, additional_constant
        ) VALUES (
            -58, 58,    -- Температура
            500, 900,   -- Давление
            0, 59,      -- Направление ветра
            0, 20,      -- Скорость ветра
            0, 200,     -- Высота
            750,        -- Константное значение
            15.9        -- Дополнительная константа
        );
    ELSE
        UPDATE measure_settings
        SET 
            min_temperature = -58,
            max_temperature = 58,
            min_pressure = 500,
            max_pressure = 900,
            min_wind_direction = 0,
            max_wind_direction = 59,
            min_wind_speed = 0,
            max_wind_speed = 20,
            min_height = 0,
            max_height = 200,
            constant_value = 750,    
            additional_constant = 15.9 
        WHERE id = 1;
    END IF;
END $$;

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

-- Таблица поправок по температуре
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

-- Функция для валидации параметров измерений
CREATE OR REPLACE FUNCTION validate_measurement(
    params measurement_params
) 
RETURNS measurement_params AS $$
DECLARE
    settings measure_settings;
BEGIN
    -- Получаем настройки
    SELECT * INTO settings FROM measure_settings LIMIT 1;
    
    -- Проверяем высоту
    IF params.height < settings.min_height OR params.height > settings.max_height THEN
        RAISE EXCEPTION 'Высота вне допустимого диапазона: %', params.height;
    END IF;

    -- Проверяем температуру
    IF params.temperature < settings.min_temperature OR params.temperature > settings.max_temperature THEN
        RAISE EXCEPTION 'Температура вне допустимого диапазона: %', params.temperature;
    END IF;

    -- Проверяем давление
    IF params.pressure < settings.min_pressure OR params.pressure > settings.max_pressure THEN
        RAISE EXCEPTION 'Давление вне допустимого диапазона: %', params.pressure;
    END IF;

    -- Проверяем направление ветра
    IF params.wind_direction < settings.min_wind_direction OR params.wind_direction > settings.max_wind_direction THEN
        RAISE EXCEPTION 'Направление ветра вне допустимого диапазона: %', params.wind_direction;
    END IF;

    -- Проверяем скорость ветра
    IF params.wind_speed < settings.min_wind_speed OR params.wind_speed > settings.max_wind_speed THEN
        RAISE EXCEPTION 'Скорость ветра вне допустимого диапазона: %', params.wind_speed;
    END IF;

    -- Все проверки пройдены, возвращаем валидированные параметры
    RETURN params;
END;
$$ LANGUAGE plpgsql;

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
    SELECT EXTRACT(DAY FROM now()), EXTRACT(HOUR FROM now()), EXTRACT(MINUTE FROM now()) INTO day, hour, minute;
    RETURN LPAD(day::TEXT, 2, '0') || LPAD(hour::TEXT, 2, '0') || LPAD(minute::TEXT, 2, '0');
END;
$$ LANGUAGE plpgsql;

-- Функция для вычисления высоты метеопоста
CREATE OR REPLACE FUNCTION get_measurement_post_height() 
RETURNS TEXT AS $$
DECLARE
    height INTEGER;
BEGIN
    SELECT height INTO height FROM measurement_input_params LIMIT 1;
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
    SELECT pressure INTO pressure FROM measurement_input_params LIMIT 1;
    deviation := pressure - (SELECT constant_value FROM measure_settings LIMIT 1);
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
    SELECT temperature INTO temperature FROM measurement_input_params LIMIT 1;
    deviation := temperature - (SELECT constant_value FROM measure_settings LIMIT 1);
    RETURN LPAD(deviation::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;


-- Функция для вставки измерений
CREATE OR REPLACE FUNCTION insert_measurement(
    p_employee_id INTEGER,
    p_measurement_type_id INTEGER,
    p_params measurement_params
) 
RETURNS INTEGER AS $$
DECLARE
    param_id INTEGER;
    batch_id INTEGER;
BEGIN
    INSERT INTO measurement_input_params(
        measurement_type_id,
        height,
        temperature,
        pressure,
        wind_direction,
        wind_speed
    ) VALUES (
        p_measurement_type_id,
        p_params.height,
        p_params.temperature,
        p_params.pressure,
        p_params.wind_direction,
        p_params.wind_speed
    ) RETURNING id INTO param_id;

    INSERT INTO measurement_batches(
        employee_id,
        measurement_input_param_id,
        started
    ) VALUES (
        p_employee_id,
        param_id,
        NOW()
    ) RETURNING id INTO batch_id;

    RETURN batch_id;
END;
$$ LANGUAGE plpgsql;

-- Отдельный скрипт для генерации тестовых данных
DO $$
DECLARE
    i INTEGER;
    user_id INTEGER;
    test_params measurement_params;
    validated_params measurement_params;
    measurement_count CONSTANT INTEGER := 100; -- Количество измерений на пользователя
    user_count CONSTANT INTEGER := 5;         -- Количество тестовых пользователей
BEGIN
    -- Добавление записей в таблицу military_ranks
    INSERT INTO military_ranks (id, description) 
    VALUES (1, 'Рядовой'), (2, 'Лейтенант')
    ON CONFLICT (id) DO NOTHING;

    -- Вставка данных в таблицу measurement_types
    INSERT INTO measurement_types (id, short_name, description)
    VALUES
        (1, 'Type1', 'Description of Measurement Type 1'),
        (2, 'Type2', 'Description of Measurement Type 2')
    ON CONFLICT (id) DO NOTHING;

    -- Добавление пользователей
    FOR i IN 1..user_count LOOP
        -- Вставка новых пользователей со случайными данными
        INSERT INTO employees(name, birthday, military_rank_id)
        VALUES (
            'User ' || i,
            '1980-01-01'::timestamp + (random() * 365 * 20 || ' days')::interval,
            (i % 2) + 1
        ) RETURNING id INTO user_id;

        -- Добавление измерений для каждого пользователя
        FOR j IN 1..measurement_count LOOP
            BEGIN
                -- Создаем параметры измерения
                test_params.height := (random() * 200)::numeric(8,2);
                test_params.temperature := (random() * (58 - (-58)) + (-58))::numeric(8,2);
                test_params.pressure := (random() * (900 - 500) + 500)::numeric(8,2);
                test_params.wind_direction := (random() * 59)::numeric(8,2);
                test_params.wind_speed := (random() * 20)::numeric(8,2);

                -- Валидируем параметры
                validated_params := validate_measurement(test_params);

                -- Вставляем измерение
                PERFORM insert_measurement(
                    user_id,
                    (j % 2) + 1,  -- Чередуем типы измерений
                    validated_params
                );

            EXCEPTION 
                WHEN OTHERS THEN
                    RAISE NOTICE 'Ошибка при создании измерения для пользователя % (попытка %): %', i, j, SQLERRM;
                    CONTINUE;
            END;
        END LOOP;
        
        RAISE NOTICE 'Создан пользователь % с измерениями', i;
    END LOOP;
END $$;

-- Проверка результатов
DO $$
DECLARE
    user_count INTEGER;
    measurement_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM employees;
    SELECT COUNT(*) INTO measurement_count FROM measurement_batches;
    
    RAISE NOTICE 'Создано пользователей: %', user_count;
    RAISE NOTICE 'Создано измерений: %', measurement_count;
END $$;