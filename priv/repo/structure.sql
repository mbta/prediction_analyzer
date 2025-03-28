--
-- PostgreSQL database dump
--

-- Dumped from database version 15.10 (Debian 15.10-1.pgdg120+1)
-- Dumped by pg_dump version 15.12 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: arrival_departure; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.arrival_departure AS ENUM (
    'arrival',
    'departure'
);


--
-- Name: environment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.environment AS ENUM (
    'prod',
    'dev-green',
    'dev-blue'
);


--
-- Name: prediction_bin; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.prediction_bin AS ENUM (
    '0-3 min',
    '3-6 min',
    '6-12 min',
    '12-30 min',
    '6-8 min',
    '8-10 min',
    '10-12 min'
);


--
-- Name: prediction_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.prediction_kind AS ENUM (
    'at_terminal',
    'mid_trip',
    'reverse'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: prediction_accuracy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prediction_accuracy (
    id bigint NOT NULL,
    service_date date NOT NULL,
    hour_of_day integer NOT NULL,
    stop_id character varying(255) NOT NULL,
    route_id character varying(255) NOT NULL,
    arrival_departure public.arrival_departure,
    bin public.prediction_bin NOT NULL,
    num_predictions integer NOT NULL,
    num_accurate_predictions integer NOT NULL,
    environment public.environment DEFAULT 'prod'::public.environment NOT NULL,
    direction_id integer,
    mean_error real,
    root_mean_squared_error real,
    kind public.prediction_kind,
    in_next_two boolean,
    minute_of_hour integer DEFAULT 0 NOT NULL
);


--
-- Name: prediction_accuracy_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.prediction_accuracy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: prediction_accuracy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.prediction_accuracy_id_seq OWNED BY public.prediction_accuracy.id;


--
-- Name: predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.predictions (
    id bigint NOT NULL,
    trip_id character varying(255),
    is_deleted boolean,
    delay integer,
    arrival_time integer,
    boarding_status character varying(255),
    departure_time integer,
    schedule_relationship character varying(255),
    stop_id character varying(255),
    stop_sequence integer,
    stops_away integer,
    vehicle_event_id bigint,
    file_timestamp integer NOT NULL,
    route_id character varying(255) NOT NULL,
    environment public.environment DEFAULT 'prod'::public.environment NOT NULL,
    vehicle_id character varying(255),
    direction_id integer,
    kind public.prediction_kind,
    nth_at_stop integer
);


--
-- Name: predictions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.predictions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: predictions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.predictions_id_seq OWNED BY public.predictions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: vehicle_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_events (
    id bigint NOT NULL,
    vehicle_id character varying(255),
    vehicle_label character varying(255),
    is_deleted boolean,
    route_id character varying(255),
    direction_id integer,
    trip_id character varying(255),
    stop_id character varying(255),
    arrival_time integer,
    departure_time integer,
    environment public.environment DEFAULT 'prod'::public.environment NOT NULL
);


--
-- Name: vehicle_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vehicle_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vehicle_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vehicle_events_id_seq OWNED BY public.vehicle_events.id;


--
-- Name: prediction_accuracy id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prediction_accuracy ALTER COLUMN id SET DEFAULT nextval('public.prediction_accuracy_id_seq'::regclass);


--
-- Name: predictions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions ALTER COLUMN id SET DEFAULT nextval('public.predictions_id_seq'::regclass);


--
-- Name: vehicle_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_events ALTER COLUMN id SET DEFAULT nextval('public.vehicle_events_id_seq'::regclass);


--
-- Name: prediction_accuracy prediction_accuracy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prediction_accuracy
    ADD CONSTRAINT prediction_accuracy_pkey PRIMARY KEY (id);


--
-- Name: predictions predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: vehicle_events vehicle_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_events
    ADD CONSTRAINT vehicle_events_pkey PRIMARY KEY (id);


--
-- Name: prediction_accuracy_service_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX prediction_accuracy_service_date_index ON public.prediction_accuracy USING btree (service_date);


--
-- Name: prediction_accuracy_stop_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX prediction_accuracy_stop_id_index ON public.prediction_accuracy USING btree (stop_id);


--
-- Name: predictions_file_timestamp_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX predictions_file_timestamp_index ON public.predictions USING btree (file_timestamp);


--
-- Name: predictions_stop_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX predictions_stop_id_index ON public.predictions USING btree (stop_id) WHERE (vehicle_event_id IS NULL);


--
-- Name: predictions_trip_id_direction_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX predictions_trip_id_direction_id_index ON public.predictions USING btree (trip_id, direction_id) WHERE (vehicle_event_id IS NULL);


--
-- Name: predictions_vehicle_event_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX predictions_vehicle_event_id_index ON public.predictions USING btree (vehicle_event_id);


--
-- Name: predictions_vehicle_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX predictions_vehicle_id_index ON public.predictions USING btree (vehicle_id) WHERE (vehicle_event_id IS NULL);


--
-- Name: vehicle_events_arrival_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vehicle_events_arrival_time_index ON public.vehicle_events USING btree (arrival_time);


--
-- Name: vehicle_events_departure_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vehicle_events_departure_time_index ON public.vehicle_events USING btree (departure_time);


--
-- Name: vehicle_events_stop_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vehicle_events_stop_id_index ON public.vehicle_events USING btree (stop_id) WHERE (departure_time IS NULL);


--
-- Name: vehicle_events_vehicle_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vehicle_events_vehicle_id_index ON public.vehicle_events USING btree (vehicle_id) WHERE (departure_time IS NULL);


--
-- Name: predictions predictions_vehicle_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.predictions
    ADD CONSTRAINT predictions_vehicle_event_id_fkey FOREIGN KEY (vehicle_event_id) REFERENCES public.vehicle_events(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20181017190602);
INSERT INTO public."schema_migrations" (version) VALUES (20181022210113);
INSERT INTO public."schema_migrations" (version) VALUES (20181025152446);
INSERT INTO public."schema_migrations" (version) VALUES (20181026133153);
INSERT INTO public."schema_migrations" (version) VALUES (20181026135330);
INSERT INTO public."schema_migrations" (version) VALUES (20181026160237);
INSERT INTO public."schema_migrations" (version) VALUES (20181029181739);
INSERT INTO public."schema_migrations" (version) VALUES (20181029192143);
INSERT INTO public."schema_migrations" (version) VALUES (20181029203022);
INSERT INTO public."schema_migrations" (version) VALUES (20181106155014);
INSERT INTO public."schema_migrations" (version) VALUES (20181112161231);
INSERT INTO public."schema_migrations" (version) VALUES (20181130203837);
INSERT INTO public."schema_migrations" (version) VALUES (20181203152039);
INSERT INTO public."schema_migrations" (version) VALUES (20190114210649);
INSERT INTO public."schema_migrations" (version) VALUES (20190315155432);
INSERT INTO public."schema_migrations" (version) VALUES (20190528184413);
INSERT INTO public."schema_migrations" (version) VALUES (20190624192925);
INSERT INTO public."schema_migrations" (version) VALUES (20190701174220);
INSERT INTO public."schema_migrations" (version) VALUES (20201019175956);
INSERT INTO public."schema_migrations" (version) VALUES (20201022151038);
INSERT INTO public."schema_migrations" (version) VALUES (20201027201115);
INSERT INTO public."schema_migrations" (version) VALUES (20201103215547);
INSERT INTO public."schema_migrations" (version) VALUES (20201112161111);
INSERT INTO public."schema_migrations" (version) VALUES (20201130194309);
INSERT INTO public."schema_migrations" (version) VALUES (20230717150451);
INSERT INTO public."schema_migrations" (version) VALUES (20230914092018);
INSERT INTO public."schema_migrations" (version) VALUES (20231005191442);
INSERT INTO public."schema_migrations" (version) VALUES (20250318190252);
