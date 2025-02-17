-- Вставка данных в таблицу measurement_types, если они еще не существуют
INSERT INTO measurement_types (id, short_name, description)
VALUES 
    (1, 'Type1', 'Description of Measurement Type 1'),
    (2, 'Type2', 'Description of Measurement Type 2')
ON CONFLICT (id) DO NOTHING;



DO $$ 
DECLARE
    i INTEGER;
    user_id INTEGER;
    height NUMERIC(8,2);
    temperature NUMERIC(8,2);
    pressure NUMERIC(8,2);
    wind_direction NUMERIC(8,2);
    wind_speed NUMERIC(8,2);
    measurement_type_id INTEGER;
BEGIN
    -- Добавление пользователей (не менее 5)
    FOR i IN 1..5 LOOP
        -- Вставка новых пользователей с случайными данными
        INSERT INTO employees(name, birthday, military_rank_id)
        VALUES ('User ' || i, '1980-01-01', (i % 2) + 1)
        RETURNING id INTO user_id;

        -- Добавление измерений для каждого пользователя (не менее 100 измерений)
        FOR measurement_type_id IN 1..2 LOOP
            FOR i IN 1..20 LOOP
                -- Генерация случайных данных для измерений
                height := (random() * 200)::numeric(8,2);  -- Высота от 0 до 200 метров
                temperature := (random() * (58 - (-58)) + (-58))::numeric(8,2);  -- Температура от -58 до 58
                pressure := (random() * (900 - 500) + 500)::numeric(8,2);  -- Давление от 500 до 900 мм рт. ст.
                wind_direction := (random() * 59)::numeric(8,2);  -- Направление ветра от 0 до 59
                wind_speed := (random() * 20)::numeric(8,2);  -- Скорость ветра от 0 до 20 м/с

                -- Вставка случайных данных в таблицу measurement_input_params
                INSERT INTO measurement_input_params(
                    measurement_type_id, 
                    height, 
                    temperature, 
                    pressure, 
                    wind_direction, 
                    wind_speed
                )
                VALUES (
                    measurement_type_id,
                    height,
                    temperature,
                    pressure,
                    wind_direction,
                    wind_speed
                );

                -- Вставка данных в таблицу measurement_batches
                INSERT INTO measurement_batches(
                    employee_id, 
                    measurement_input_param_id, 
                    started
                )
                VALUES (
                    user_id, 
                    (SELECT id FROM measurement_input_params ORDER BY id DESC LIMIT 1), 
                    NOW()
                );
            END LOOP;
        END LOOP;
    END LOOP;
END $$;
