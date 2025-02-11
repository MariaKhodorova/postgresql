-- SCHEMA: system

-- Создание схемы
CREATE SCHEMA IF NOT EXISTS system
    AUTHORIZATION admin;

-- Создание таблицы measurment_bath
CREATE TABLE IF NOT EXISTS system.measurment_bath
(
    id integer NOT NULL,
    startperiod timestamp without time zone DEFAULT now(),
    positionx numeric(3,2),
    positiony numeric(3,2),
    user_id integer NOT NULL,  
    CONSTRAINT measurment_bath_pkey PRIMARY KEY (id),
    CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES system.users (id) ON UPDATE NO ACTION ON DELETE NO ACTION
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.measurment_bath
    OWNER to admin;

-- Создание таблицы measurment_params
CREATE TABLE IF NOT EXISTS system.measurment_params
(
    id integer NOT NULL DEFAULT nextval('system.measurment_params_seq'::regclass),
    measurtment_type_id integer NOT NULL,
    measurment_bath_id integer NOT NULL,
    height numeric(8,2),
    temperature numeric(8,2),
    pressure numeric(8,2),
    windspeed numeric(8,2),
    winddirection numeric(8,2),
    speedbullet numeric(8,2),
    CONSTRAINT measurment_params_pkey PRIMARY KEY (id)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.measurment_params
    OWNER to admin;

-- Создание таблицы measurment_type
CREATE TABLE IF NOT EXISTS system.measurment_type
(
    id integer NOT NULL,
    name character varying(100) COLLATE pg_catalog."default",
    CONSTRAINT measurment_type_pkey PRIMARY KEY (id)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.measurment_type
    OWNER to admin;

-- Создание последовательности для measurment_bath
CREATE SEQUENCE IF NOT EXISTS system.measurment_bath_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE system.measurment_bath_seq
    OWNER TO admin;

-- Создание последовательности для measurment_params
CREATE SEQUENCE IF NOT EXISTS system.measurment_params_seq
    INCREMENT 1
    START 2
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE system.measurment_params_seq
    OWNER TO admin;

-- Создание таблицы военных должностей
CREATE TABLE IF NOT EXISTS system.military_positions
(
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
    position_name character varying(100) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT military_positions_pkey PRIMARY KEY (id)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.military_positions
    OWNER to admin;

-- Создание таблицы пользователей
CREATE TABLE IF NOT EXISTS system.users
(
    id integer NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    middle_name character varying(100),
    position_id integer NOT NULL,
    active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT fk_position FOREIGN KEY (position_id) REFERENCES system.military_positions (id) ON UPDATE NO ACTION ON DELETE NO ACTION
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.users
    OWNER to admin;


ALTER TABLE system.measurment_bath DROP COLUMN IF EXISTS username;



INSERT INTO system.military_positions (id, position_name, description) VALUES
    (1, 'Лейтенант', 'Младший офицерский состав'),
    (2, 'Старший лейтенант', 'Младший офицерский состав'),
    (3, 'Капитан', 'Младший офицерский состав');



INSERT INTO system.users (id, first_name, last_name, middle_name, position_id, active) VALUES
    (1, 'Иван', 'Иванов', 'Иванович', 1, true),
    (2, 'Петр', 'Алексеев', 'Петрович', 2, true);


INSERT INTO system.measurment_type (id, name) VALUES
    (1, 'ДМК'),
    (2, 'ВР');


INSERT INTO system.measurment_bath (id, startperiod, positionx, positiony, user_id) VALUES
    (1, '2025-01-31 10:20:00', 4.30, 2.90, 1),
    (2, '2025-01-31 10:30:00', 5.50, 2.00, 2);


-- Устанавливаем значение последовательности для measurment_bath
SELECT setval('system.measurment_bath_seq', (SELECT MAX(id) FROM system.measurment_bath));


INSERT INTO system.measurment_params (measurtment_type_id, measurment_bath_id, height, temperature, pressure, windspeed, winddirection, speedbullet) VALUES
    (1, 1, 30.34, 15.60, 737.00, 4.00, 2.00, 100.00),
    (2, 2, 10.34, 18.60, 776.00, 7.00, 1.00, 300.00);

-- Устанавливаем значение последовательности для measurment_params
SELECT setval('system.measurment_params_seq', (SELECT MAX(id) FROM system.measurment_params));
