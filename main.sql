-- SCHEMA: system

-- DROP SCHEMA IF EXISTS system ;

CREATE SCHEMA IF NOT EXISTS system
    AUTHORIZATION admin;
    

-- Table: system.measurment_bath

-- DROP TABLE IF EXISTS system.measurment_bath;

CREATE TABLE IF NOT EXISTS system.measurment_bath
(
    id integer NOT NULL,
    startperiod timestamp without time zone DEFAULT now(),
    positionx numeric(3,2),
    positiony numeric(3,2),
    username character varying COLLATE pg_catalog."default",
    CONSTRAINT history_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.measurment_bath
    OWNER to admin;


-- Table: system.measurment_params

-- DROP TABLE IF EXISTS system.measurment_params;

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


-- Table: system.measurment_type

-- DROP TABLE IF EXISTS system.measurment_type;

CREATE TABLE IF NOT EXISTS system.measurment_type
(
    id integer NOT NULL,
    name character varying(100) COLLATE pg_catalog."default",
    CONSTRAINT measurment_type_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.measurment_type
    OWNER to admin;


-- SEQUENCE: system.measurment_bath_seq

-- DROP SEQUENCE IF EXISTS system.measurment_bath_seq;

CREATE SEQUENCE IF NOT EXISTS system.measurment_bath_seq
    INCREMENT 1
    START 1
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE system.measurment_bath_seq
    OWNER TO admin;
    
     
-- SEQUENCE: system.measurment_params_seq

-- DROP SEQUENCE IF EXISTS system.measurment_params_seq;

CREATE SEQUENCE IF NOT EXISTS system.measurment_params_seq
    INCREMENT 1
    START 2
    MINVALUE 1
    MAXVALUE 9223372036854775807
    CACHE 1;

ALTER SEQUENCE system.measurment_params_seq
    OWNER TO admin;
    
    
    
    
-- Create table for military positions
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

-- Create table for system users
CREATE TABLE IF NOT EXISTS system.users
(
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
    username character varying(50) NOT NULL UNIQUE,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    middle_name character varying(100),
    position_id integer NOT NULL,
    active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT fk_position FOREIGN KEY (position_id)
        REFERENCES system.military_positions (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS system.users
    OWNER to admin;

-- Create index on username for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_username
    ON system.users (username);

-- Modify measurement_bath table
-- First, rename the existing username column to prevent conflicts
ALTER TABLE system.measurment_bath 
    RENAME COLUMN username TO username_old;

-- Add new column referencing users table
ALTER TABLE system.measurment_bath 
    ADD COLUMN user_id integer;

-- Add foreign key constraint
ALTER TABLE system.measurment_bath
    ADD CONSTRAINT fk_user FOREIGN KEY (user_id)
        REFERENCES system.users (id)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;

-- Create index on user_id for faster joins
CREATE INDEX IF NOT EXISTS idx_measurement_bath_user_id
    ON system.measurment_bath (user_id);



INSERT INTO system.military_positions (position_name, description) VALUES
    ('Лейтенант', 'Младший офицерский состав'),
    ('Старший лейтенант', 'Младший офицерский состав'),
    ('Капитан', 'Младший офицерский состав');


INSERT INTO system.users (username, first_name, last_name, middle_name, position_id, active) VALUES
    ('Ivanov', 'Иван', 'Иванов', 'Иванович', 1, true),
    ('Alekseev', 'Петр', 'Алексеев', 'Петрович', 2, true);


INSERT INTO system.measurment_type (id, name) VALUES
    (1, 'ДМК'),
    (2, 'ВР');


INSERT INTO system.measurment_bath (id, startperiod, positionx, positiony, user_id) VALUES
    (1, '2025-01-31 10:20:00', 4.30, 2.90, (SELECT id FROM system.users WHERE username = 'Potatov')),
    (2, '2025-01-31 10:30:00', 5.50, 2.00, (SELECT id FROM system.users WHERE username = 'Tomatov'));

-- Set the sequence value for measurement_bath
SELECT setval('system.measurment_bath_seq', (SELECT MAX(id) FROM system.measurment_bath));


INSERT INTO system.measurment_params (measurtment_type_id, measurment_bath_id, height, temperature, pressure, windspeed, winddirection, speedbullet) VALUES
    (1, 1, 30.34, 15.60, 737.00, 4.00, 2.00, 100.00),
    (2, 2, 10.34, 18.60, 776.00, 7.00, 1.00, 300.00);

-- Set the sequence value for measurement_params
SELECT setval('system.measurment_params_seq', (SELECT MAX(id) FROM system.measurment_params));
  